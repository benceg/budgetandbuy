import CoreData
import CoreLocation
import UserNotifications
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Arrivals")

/// Notices when you arrive at one of your stores and switches on shopping mode
/// there. Location is checked by iOS on the device; nothing is sent anywhere.
@MainActor
final class StoreArrivalMonitor {
    static let shared = StoreArrivalMonitor()
    static let enabledKey = "detectsStoreArrivals"

    /// iOS watches at most 20 regions per app.
    private static let limit = 20
    private static let radius: CLLocationDistance = 100

    private var monitor: CLMonitor?
    private var session: CLServiceSession?
    private var events: Task<Void, Never>?

    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    func setEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if enabled {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
        await refresh()
    }

    /// Watches every store with a location, or nothing when switched off.
    /// Call on launch, including background launches for an arrival, and
    /// whenever stores change.
    func refresh() async {
        let request = NSFetchRequest<Store>(entityName: "Store")
        request.predicate = NSPredicate(format: "hasLocation == YES")
        request.sortDescriptors = Store.oldestFirst
        let stores = (try? PersistenceController.shared.viewContext.fetch(request)) ?? []

        guard isEnabled, !stores.isEmpty else {
            await stop()
            return
        }
        if session == nil {
            session = CLServiceSession(authorization: .always)
        }

        let monitor = await currentMonitor()
        var wanted: [String: CLMonitor.CircularGeographicCondition] = [:]
        for store in stores.prefix(Self.limit) {
            guard let id = store.uuid?.uuidString, let coordinate = store.coordinate else { continue }
            wanted[id] = CLMonitor.CircularGeographicCondition(center: coordinate, radius: Self.radius)
        }
        for id in await monitor.identifiers where wanted[id] == nil {
            await monitor.remove(id)
        }
        for (id, condition) in wanted {
            if let existing = await monitor.record(for: id)?.condition as? CLMonitor.CircularGeographicCondition,
               existing.center.latitude == condition.center.latitude,
               existing.center.longitude == condition.center.longitude {
                continue
            }
            await monitor.add(condition, identifier: id, assuming: .unsatisfied)
        }
    }

    private func stop() async {
        if let monitor {
            for id in await monitor.identifiers {
                await monitor.remove(id)
            }
        }
        session?.invalidate()
        session = nil
    }

    private func currentMonitor() async -> CLMonitor {
        if let monitor { return monitor }
        let monitor = await CLMonitor("stores")
        self.monitor = monitor
        events = Task {
            do {
                for try await event in await monitor.events where event.state == .satisfied {
                    arrived(atStoreWithID: event.identifier)
                }
            } catch {
                logger.error("Store monitoring stopped: \(error)")
            }
        }
        return monitor
    }

    private func arrived(atStoreWithID id: String) {
        guard UserDefaults.standard.string(forKey: "shoppingStoreID") != id,
              let uuid = UUID(uuidString: id) else { return }
        let request = NSFetchRequest<Store>(entityName: "Store")
        request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        request.fetchLimit = 1
        guard let store = try? PersistenceController.shared.viewContext.fetch(request).first else { return }

        UserDefaults.standard.set(id, forKey: "shoppingStoreID")

        let content = UNMutableNotificationContent()
        content.title = String(localized: "You’re at \(store.name ?? "")")
        content.body = String(localized: "Shopping mode is on. Tick things off as you go to keep prices up to date.")
        let notification = UNNotificationRequest(identifier: "arrival-\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(notification)
    }
}
