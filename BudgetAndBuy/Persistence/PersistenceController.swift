import CloudKit
import CoreLocation
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
            if let sharedStore {
                let request = NSFetchRequest<Household>(entityName: "Household")
                request.affectedStores = [sharedStore]
                for household in try viewContext.fetch(request) {
                    household.mergeDuplicateProducts()
                }
            }
        } catch {
            logger.error("Merging duplicates failed: \(error)")
        }
        viewContext.saveIfNeeded()
    }

    nonisolated static let sharedStoreFileName = "shared.sqlite"

    nonisolated static func isSharedStore(_ store: NSPersistentStore?) -> Bool {
        store?.url?.lastPathComponent == sharedStoreFileName
    }

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
        weekly.budgetMinor = 5_000
        household.monthlyBudgetMinor = 40_000
        for (name, category) in [
            ("Semi-skimmed milk 4 pints", ProductCategory.dairyAndEggs), ("Sourdough 800g", .bakery), ("Bananas", .fruitAndVeg),
            ("Free-range eggs 6 pack", .dairyAndEggs), ("Cheddar 400g", .dairyAndEggs),
        ] {
            weekly.addItem(named: name)?.product?.category = category
        }
        weekly.addItem(named: "Bananas")
        weekly.addItem(named: "Coffee beans")?.setChecked(true)

        let party = household.addList()
        party.name = "Saturday BBQ"
        party.colorName = "apricot"
        party.symbolName = "flame.fill"
        party.addItem(named: "Burgers")

        let aldi = household.addStore()
        aldi.name = "Aldi"
        aldi.colorName = "slate"
        aldi.travelMinutes = 20
        aldi.distanceKm = 14
        aldi.coordinate = CLLocationCoordinate2D(latitude: 51.4881, longitude: -0.0489)
        let coop = household.addStore()
        coop.name = "Co-op"
        coop.colorName = "sea"
        coop.travel = .walk
        coop.travelMinutes = 4
        coop.distanceKm = 0.3
        coop.coordinate = CLLocationCoordinate2D(latitude: 51.4985, longitude: -0.0627)
        for (name, aldiPrice, coopPrice) in [
            ("Semi-skimmed milk 4 pints", 145, 175), ("Sourdough 800g", 129, 250), ("Bananas", 17, 25), ("Cheddar 400g", 299, 425),
        ] {
            let (name, size) = ProductSize.split(name)
            let product = household.product(named: name, size: size)
            aldi.recordPrice(Int64(aldiPrice), for: product)
            coop.recordPrice(Int64(coopPrice), for: product)
        }
        coop.recordPrice(325, for: household.product(named: "Free-range eggs", size: ProductSize(amount: 6, unit: .pack)))
        aldi.markUnavailable(household.product(named: "Coffee beans"))

        for (daysAgo, store, spent, saved, carbon, carbonSaved) in [
            (2, aldi, 4_120, 980, 4.8, -4.8), (9, coop, 1_460, -210, 0, 4.8), (16, aldi, 5_235, 1_140, 4.8, -4.8),
        ] {
            let trip = household.insertRelated(Trip.self)
            trip.household = household
            trip.store = store
            trip.storeName = store.name
            trip.listName = weekly.name
            trip.travelMode = store.travelMode
            trip.createdAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)
            trip.spentMinor = Int64(spent)
            trip.savedMinor = Int64(saved)
            trip.comparedStoreName = store == aldi ? coop.name : aldi.name
            trip.carbonKg = carbon
            trip.carbonSavedKg = carbonSaved
        }
        #if DEBUG
        if DebugLaunch.usesSampleData {
            UserDefaults.standard.set(DebugLaunch.isShopping ? coop.uuid?.uuidString : "", forKey: "shoppingStoreID")
        }
        #endif

        controller.viewContext.saveIfNeeded()
        return controller
    }()
}
