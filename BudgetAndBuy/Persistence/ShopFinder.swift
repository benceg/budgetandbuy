import CoreLocation
import MapKit
import Observation
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "ShopFinder")

/// Finds shops near you, or by name, with Apple Maps, and estimates the
/// journey to one. Your location is only used on the device and by Maps.
@MainActor
@Observable
final class ShopFinder {
    enum Access { case unknown, allowed, denied }

    private(set) var access: Access = .unknown
    private(set) var location: CLLocation?
    private(set) var nearby: [MKMapItem] = []
    private(set) var results: [MKMapItem] = []
    private(set) var isSearching = false

    private var session: CLServiceSession?

    // Groceries and toiletries; anything else can be found by name.
    private static let categories: [MKPointOfInterestCategory] = [.foodMarket, .bakery, .pharmacy]

    // Views create this as @State, which builds a new one each time they're
    // redrawn and keeps the first; so nothing here touches Core Location
    // until start() runs.
    init() {}

    private func updateAccess() {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: access = .allowed
        case .denied, .restricted: access = .denied
        default: access = .unknown
        }
    }

    /// Asks for your location if needed, then lists shops around you.
    func start() async {
        updateAccess()
        session = CLServiceSession(authorization: .whenInUse)
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                updateAccess()
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    access = .denied
                    break
                }
                if let location = update.location {
                    self.location = location
                    access = .allowed
                    break
                }
            }
        } catch {
            logger.error("Location updates failed: \(error)")
        }
        session = nil
        await loadNearby()
    }

    private func loadNearby() async {
        guard let location else { return }
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 4_000)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: Self.categories)
        do {
            let items = try await MKLocalSearch(request: request).start().mapItems
            nearby = sortedByDistance(items)
        } catch {
            logger.error("Nearby search failed: \(error)")
        }
    }

    func search(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = .pointOfInterest
        if let location {
            request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 30_000, longitudinalMeters: 30_000)
        }
        do {
            let items = try await MKLocalSearch(request: request).start().mapItems
            results = sortedByDistance(items)
        } catch {
            results = []
        }
    }

    func distance(to item: MKMapItem) -> CLLocationDistance? {
        location?.distance(from: item.location)
    }

    private func sortedByDistance(_ items: [MKMapItem]) -> [MKMapItem] {
        guard let location else { return items }
        return items.sorted { location.distance(from: $0.location) < location.distance(from: $1.location) }
    }

    /// Minutes and kilometres from where you are, one way.
    func journey(to item: MKMapItem, by mode: TravelMode) async -> (minutes: Int, kilometres: Double)? {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = item
        request.transportType = switch mode {
        case .walk: .walking
        case .cycle: .cycling
        case .drive: .automobile
        case .transit: .transit
        }
        do {
            let eta = try await MKDirections(request: request).calculateETA()
            return (max(1, Int((eta.expectedTravelTime / 60).rounded())), eta.distance / 1_000)
        } catch {
            // Maps can't time every kind of trip everywhere; estimate from the distance instead.
            guard let metres = distance(to: item) else { return nil }
            let kilometres = metres / 1_000 * 1.3
            return (max(1, Int((kilometres / mode.typicalSpeedKmh * 60).rounded())), kilometres)
        }
    }

    /// The way you'd most likely go: on foot if it's close, otherwise by car.
    func likelyMode(to item: MKMapItem) -> TravelMode {
        guard let metres = distance(to: item) else { return .drive }
        return metres < 1_200 ? .walk : .drive
    }
}

extension TravelMode {
    fileprivate var typicalSpeedKmh: Double {
        switch self {
        case .walk: 4.8
        case .cycle: 15
        case .drive: 30
        case .transit: 18
        }
    }
}

extension ShopPlace {
    /// A place found in Maps, with its name and identifier.
    init(_ item: MKMapItem) {
        self.init(address: item)
        name = item.name ?? ""
        placeID = item.identifier?.rawValue
    }

    /// Only where an item is: for an address found by hand, which has no
    /// name of its own and isn't a place in Maps.
    init(address item: MKMapItem) {
        let full = item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
            ?? item.address?.fullAddress ?? ""
        let short = item.address?.shortAddress ?? item.addressRepresentations?.cityWithContext ?? full
        self.init(name: "", address: short, fullAddress: full, placeID: nil,
                  latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
    }

    /// The address at a point on the map, or nil if Maps hasn't one, such as
    /// in the middle of a field.
    static func lookUp(_ coordinate: CLLocationCoordinate2D) async -> ShopPlace? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        var place = ShopPlace(address: item)
        guard !place.fullAddress.isEmpty else { return nil }
        // Keep the point that was chosen, not the middle of the address Maps found.
        place.latitude = coordinate.latitude
        place.longitude = coordinate.longitude
        return place
    }
}
