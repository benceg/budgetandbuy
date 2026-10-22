import CoreData
import CoreLocation

/// Where a shop is: its address and the point on the map. Every shop has one.
struct ShopPlace: Hashable {
    /// What Maps calls it, or empty for an address picked by hand.
    var name: String
    /// Short enough to show under a shop's name, such as "200 Brighton Road, Coulsdon".
    var address: String
    /// Such as "200 Brighton Road, Coulsdon, CR5 2PL".
    var fullAddress: String
    /// Maps' identifier for the place, for shops found in Maps.
    var placeID: String?
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

extension Household {
    /// The shop you already have at a place, if any: the same place in Maps,
    /// or, for a shop placed by hand, the same address. Names don't count, so
    /// two shops can both be called "Tesco".
    func store(at place: ShopPlace) -> Store? {
        (stores ?? []).first { !$0.isDeleted && $0.isSamePlace(as: place) }
    }

    /// Adds a shop at a place. If you already have a shop there, nothing is
    /// added and that one is returned as it was.
    @discardableResult
    func addStore(named name: String, at place: ShopPlace, colorName: String? = nil) -> Store {
        if let existing = store(at: place) { return existing }
        let store = addStore()
        store.name = name
        store.place = place
        store.colorName = colorName ?? nextStoreColorName
        return store
    }

    /// The first swatch none of the household's shops uses yet.
    var nextStoreColorName: String {
        let used = Set((stores ?? []).compactMap(\.colorName))
        return ListAppearance.colorNames.first { !used.contains($0) } ?? "slate"
    }
}

extension Store: Identifiable {}

extension Store {
    var place: ShopPlace {
        get {
            ShopPlace(name: name ?? "", address: address ?? "", fullAddress: fullAddress ?? "",
                      placeID: placeID, latitude: latitude, longitude: longitude)
        }
        set {
            address = newValue.address
            fullAddress = newValue.fullAddress
            placeID = newValue.placeID
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    func isSamePlace(as place: ShopPlace) -> Bool {
        if let placeID, let other = place.placeID { return placeID == other }
        return Self.normalized(fullAddress ?? "") == Self.normalized(place.fullAddress)
            && !(fullAddress ?? "").isEmpty
    }

    private static func normalized(_ address: String) -> String {
        address.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Whether another of these shops has the same name, so that where space
    /// is short, this one needs its address to tell them apart.
    func sharesName(with stores: some Sequence<Store>) -> Bool {
        let name = (self.name ?? "").lowercased()
        return stores.contains { $0 != self && ($0.name ?? "").lowercased() == name }
    }
}
