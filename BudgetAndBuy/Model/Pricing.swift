import CoreData
import CoreLocation
import Foundation

/// Prices are stored as whole minor units (pence) so sums are exact.
enum Money {
    static var currencyCode: String { Locale.current.currency?.identifier ?? "GBP" }
    static var currencySymbol: String { Locale.current.currencySymbol ?? "£" }

    static func format(_ minorUnits: Int64) -> String {
        (Decimal(minorUnits) / 100).formatted(.currency(code: currencyCode))
    }

    /// The amount as you'd type it, without the currency symbol: 115 → "1.15".
    static func editableText(_ minorUnits: Int64) -> String {
        (Decimal(minorUnits) / 100).formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }

    /// Parses what someone typed into a price field. Nil for anything that isn't
    /// a non-negative amount.
    static func minorUnits(from text: String, locale: Locale = .current) -> Int64? {
        let separator = locale.decimalSeparator ?? "."
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: separator, with: ".")
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned), value >= 0 else { return nil }
        var unrounded = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &unrounded, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}

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
