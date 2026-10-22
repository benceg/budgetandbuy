import CoreLocation
import MapKit
import Observation
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Journeys")

/// Where you are, and how long it takes by car and on foot to get from there
/// to your shops, or from one shop to another. Journeys are worked out by
/// Maps when they're needed and kept only while the app runs. Your location
/// is only used on the device and by Maps.
@MainActor
@Observable
final class Journeys {
    enum Access { case notAsked, allowed, denied }

    static let shared = Journeys()

    private(set) var access: Access = .notAsked
    /// Where journeys from you start. It only moves once you've gone far
    /// enough for them to change, so they aren't worked out again for every
    /// step you take.
    private(set) var location: CLLocation?

    private var legs: [Leg: Journey] = [:]
    @ObservationIgnored private var pending: Set<Leg> = []
    @ObservationIgnored private var lastFix: Date?
    @ObservationIgnored private var session: CLServiceSession?

    /// How far you move before journeys from you are worked out again.
    private static let refreshDistance: CLLocationDistance = 200

    private init() {
        updateAccess()
    }

    private func updateAccess() {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: access = .allowed
        case .denied, .restricted: access = .denied
        default: access = .notAsked
        }
    }

    /// Finds where you are. Without `asking`, it doesn't ask for permission:
    /// screens show a prompt to turn Location on instead.
    func locate(asking: Bool = false) async {
        updateAccess()
        guard access == .allowed || (access == .notAsked && asking) else { return }
        // Once a minute is plenty for journeys to shops.
        if let lastFix, location != nil, Date.now.timeIntervalSince(lastFix) < 60 { return }
        session = CLServiceSession(authorization: .whenInUse)
        defer { session = nil }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    access = .denied
                    return
                }
                if let fix = update.location {
                    access = .allowed
                    lastFix = .now
                    if location.map({ $0.distance(from: fix) >= Self.refreshDistance }) ?? true {
                        location = fix
                    }
                    return
                }
            }
        } catch {
            logger.error("Location updates failed: \(error)")
        }
    }

    /// Asks for permission to use your location, then finds it.
    func requestAccess() async {
        await locate(asking: true)
    }

    // MARK: Journeys

    /// From where you are to a store, once it's been worked out.
    func fromHere(to store: Store) -> Journey? {
        location.flatMap { legs[Leg(from: $0.coordinate, to: store.coordinate)] }
    }

    func between(_ start: Store, and end: Store) -> Journey? {
        legs[Leg(from: start.coordinate, to: end.coordinate)]
    }

    /// Works out journeys from where you are to each store.
    func load(to stores: [Store]) async {
        await locate()
        guard let location else { return }
        for store in stores {
            await load(Leg(from: location.coordinate, to: store.coordinate))
        }
    }

    /// Works out each leg of a route: to the first store from where you are,
    /// if your location is on, then from each store to the next.
    func load(route stores: [Store]) async {
        await locate()
        var legs: [Leg] = []
        if let location, let first = stores.first {
            legs.append(Leg(from: location.coordinate, to: first.coordinate))
        }
        for (start, end) in zip(stores, stores.dropFirst()) {
            legs.append(Leg(from: start.coordinate, to: end.coordinate))
        }
        for leg in legs {
            await load(leg)
        }
    }

    private func load(_ leg: Leg) async {
        guard legs[leg] == nil, !pending.contains(leg) else { return }
        pending.insert(leg)
        defer { pending.remove(leg) }
        async let drive = minutes(for: leg, by: .automobile)
        async let walk = minutes(for: leg, by: .walking)
        let estimate = Journey(estimatingStraightLine: leg.straightLine)
        legs[leg] = Journey(driveMinutes: await drive ?? estimate.driveMinutes, walkMinutes: await walk ?? estimate.walkMinutes)
    }

    private func minutes(for leg: Leg, by transport: MKDirectionsTransportType) async -> Int? {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: leg.start, address: nil)
        request.destination = MKMapItem(location: leg.end, address: nil)
        request.transportType = transport
        // Maps can't time every kind of trip everywhere; the caller estimates instead.
        guard let eta = try? await MKDirections(request: request).calculateETA() else { return nil }
        return max(1, Int((eta.expectedTravelTime / 60).rounded()))
    }
}

/// A journey between two points, to about a metre.
private struct Leg: Hashable {
    let fromLatitude: Int, fromLongitude: Int, toLatitude: Int, toLongitude: Int

    init(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        fromLatitude = Int((start.latitude * 100_000).rounded())
        fromLongitude = Int((start.longitude * 100_000).rounded())
        toLatitude = Int((end.latitude * 100_000).rounded())
        toLongitude = Int((end.longitude * 100_000).rounded())
    }

    var start: CLLocation { CLLocation(latitude: Double(fromLatitude) / 100_000, longitude: Double(fromLongitude) / 100_000) }
    var end: CLLocation { CLLocation(latitude: Double(toLatitude) / 100_000, longitude: Double(toLongitude) / 100_000) }
    var straightLine: CLLocationDistance { start.distance(from: end) }
}
