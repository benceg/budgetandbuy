import CoreData
import CoreLocation
import Foundation

enum TravelMode: String, CaseIterable, Identifiable {
    case walk, cycle, drive, transit

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .walk: "Walk"
        case .cycle: "Cycle"
        case .drive: "Drive"
        case .transit: "Transit"
        }
    }

    var symbolName: String {
        switch self {
        case .walk: "figure.walk"
        case .cycle: "bicycle"
        case .drive: "car"
        case .transit: "bus"
        }
    }

    func journey(minutes: Int16) -> String {
        switch self {
        case .walk: String(localized: "\(minutes) min walk")
        case .cycle: String(localized: "\(minutes) min cycle")
        case .drive: String(localized: "\(minutes) min drive")
        case .transit: String(localized: "\(minutes) min by public transport")
        }
    }
}

extension Household {
    func addStore() -> Store {
        let store = insertRelated(Store.self)
        store.household = self
        return store
    }
}

extension Store {
    var travel: TravelMode {
        get { travelMode.flatMap(TravelMode.init(rawValue:)) ?? .drive }
        set { travelMode = newValue.rawValue }
    }

    var journey: String { travel.journey(minutes: travelMinutes) }

    var coordinate: CLLocationCoordinate2D? {
        get { hasLocation ? CLLocationCoordinate2D(latitude: latitude, longitude: longitude) : nil }
        set {
            hasLocation = newValue != nil
            latitude = newValue?.latitude ?? 0
            longitude = newValue?.longitude ?? 0
        }
    }

    /// The newest price for each product seen here.
    var currentPrices: [Price] {
        Dictionary(grouping: (prices ?? []).filter { $0.product != nil }) { $0.product!.objectID }
            .values
            .compactMap { $0.max(by: Price.isOlder) }
    }

    /// Records a price seen today. Seeing the same price again on the same day
    /// changes nothing; otherwise it becomes the current price.
    @discardableResult
    func recordPrice(_ amountMinor: Int64, for product: Product, on date: Date = .now) -> Price {
        if let latest = product.latestPrice(at: self),
           latest.amountMinor == amountMinor,
           let seen = latest.createdAt,
           Calendar.current.isDate(seen, inSameDayAs: date) {
            return latest
        }
        let price = insertRelated(Price.self)
        price.amountMinor = amountMinor
        price.createdAt = date
        price.product = product
        price.store = self
        return price
    }

    /// Forgets every price recorded for a product here.
    func forgetPrices(of product: Product) {
        for price in prices ?? [] where price.product == product {
            managedObjectContext?.delete(price)
        }
    }
}

extension Product {
    func latestPrice(at store: Store) -> Price? {
        (prices ?? []).filter { $0.store == store }.max(by: Price.isOlder)
    }
}

/// What a set of items costs at one store, counting only the items it has prices for.
struct StoreTotal: Equatable {
    var amountMinor: Int64 = 0
    var pricedCount = 0
    var itemCount = 0

    init(items: some Sequence<Item>, at store: Store) {
        for item in items {
            itemCount += 1
            if let price = item.product?.latestPrice(at: store) {
                pricedCount += 1
                amountMinor += price.amountMinor * Int64(item.quantity)
            }
        }
    }
}
