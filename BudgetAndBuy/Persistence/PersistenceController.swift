import CloudKit
import CoreData
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Persistence")

/// Owns the Core Data stack. Data lives in two stores, each mirrored to iCloud:
/// the private database (households you own) and the shared database
/// (households other people have shared with you).
@MainActor
final class PersistenceController {
    static let shared = PersistenceController()
    static let cloudKitContainerIdentifier = "iCloud.app.budgetandbuy"

    // Loaded once: several containers built from separate copies of one model
    // confuse Core Data about which entity a class belongs to.
    private static let model: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "BudgetAndBuy", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("BudgetAndBuy.momd is missing from the app bundle")
        }
        return model
    }()

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    private var remoteChangeObserver: (any NSObjectProtocol)?

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "BudgetAndBuy", managedObjectModel: Self.model)
        container.persistentStoreDescriptions = inMemory
            ? [Self.inMemoryDescription()]
            : [Self.cloudDescription(scope: .private), Self.cloudDescription(scope: .shared)]

        container.loadPersistentStores { description, error in
            if let error {
                fatalError("Couldn't load \(description.url?.lastPathComponent ?? "store"): \(error)")
            }
        }
        for store in container.persistentStoreCoordinator.persistentStores {
            if store.url?.lastPathComponent == Self.sharedStoreFileName {
                sharedStore = store
            } else {
                privateStore = store
            }
        }

        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.transactionAuthor = "app"

        ensureHousehold()
        if !inMemory { observeRemoteChanges() }
    }

    /// The household this device owns, created on first launch.
    @discardableResult
    func ensureHousehold() -> Household {
        let request = NSFetchRequest<Household>(entityName: "Household")
        request.sortDescriptors = Household.oldestFirst
        request.fetchLimit = 1
        if let privateStore { request.affectedStores = [privateStore] }

        if let household = try? viewContext.fetch(request).first {
            return household
        }
        let household = Household.create(in: viewContext)
        if let privateStore { viewContext.assign(household, to: privateStore) }
        viewContext.saveIfNeeded()
        return household
    }

    private func observeRemoteChanges() {
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.mergeDuplicates() }
        }
    }

    private func mergeDuplicates() {
        do {
            try viewContext.mergeDuplicateHouseholds(in: privateStore)
        } catch {
            logger.error("Merging duplicate households failed: \(error)")
        }
        viewContext.saveIfNeeded()
    }

    private static let sharedStoreFileName = "shared.sqlite"

    private static func cloudDescription(scope: CKDatabase.Scope) -> NSPersistentStoreDescription {
        let fileName = scope == .shared ? sharedStoreFileName : "private.sqlite"
        let description = NSPersistentStoreDescription(
            url: NSPersistentContainer.defaultDirectoryURL().appending(path: fileName)
        )
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)
        options.databaseScope = scope
        description.cloudKitContainerOptions = options
        return description
    }

    private static func inMemoryDescription() -> NSPersistentStoreDescription {
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        return description
    }
}

extension NSManagedObjectContext {
    func saveIfNeeded() {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            logger.error("Save failed: \(error)")
            rollback()
        }
    }
}

extension PersistenceController {
    /// Sample data for SwiftUI previews.
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let household = controller.ensureHousehold()

        let weekly = household.addList()
        weekly.name = "Weekly Shop"
        for name in ["Semi-skimmed milk", "Sourdough", "Bananas", "Free-range eggs", "Cheddar"] {
            weekly.addItem(named: name)
        }
        weekly.addItem(named: "Bananas")
        weekly.addItem(named: "Coffee beans")?.setChecked(true)

        let party = household.addList()
        party.name = "Saturday BBQ"
        party.colorName = "orange"
        party.symbolName = "flame.fill"
        party.addItem(named: "Burgers")

        controller.viewContext.saveIfNeeded()
        return controller
    }()
}
