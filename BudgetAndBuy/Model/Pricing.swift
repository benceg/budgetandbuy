import CoreData
import CoreLocation
import Foundation

extension Household {
    func addStore() -> Store {
        let store = insertRelated(Store.self)
        store.household = self
        return store
    }
}

extension Store {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// The newest price for each product sold here.
    var currentPrices: [Price] {
        currentSightings.filter { !$0.isUnavailable }
    }

    /// Products last seen not being sold here.
    var unavailableProducts: [Product] {
        currentSightings.filter(\.isUnavailable).compactMap(\.product)
    }

    /// The newest record for each product: a price, or not sold here.
    private var currentSightings: [Price] {
        Dictionary(grouping: (prices ?? []).filter { $0.product != nil }) { $0.product!.objectID }
            .values
            .compactMap { $0.max(by: Price.isOlder) }
    }

    /// Records a price seen today. Seeing the same price again on the same day
    /// changes nothing; otherwise it becomes the current price, and the product
    /// counts as sold here again if it had been marked otherwise.
    @discardableResult
    func recordPrice(_ amountMinor: Int64, for product: Product, on date: Date = .now) -> Price {
        if let latest = product.latestSighting(at: self),
           !latest.isUnavailable,
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

    /// Notes that a product isn't sold here. Its old prices are kept, and
    /// come back if it's marked as sold here again.
    func markUnavailable(_ product: Product, on date: Date = .now) {
        guard !product.isUnavailable(at: self) else { return }
        let note = insertRelated(Price.self)
        note.isUnavailable = true
        note.createdAt = date
        note.product = product
        note.store = self
    }

    /// Undoes `markUnavailable`, back to the last price seen, if any.
    func markAvailable(_ product: Product) {
        for price in prices ?? [] where price.product == product && price.isUnavailable {
            managedObjectContext?.delete(price)
        }
    }

    /// Forgets every price recorded for a product here.
    func forgetPrices(of product: Product) {
        for price in prices ?? [] where price.product == product {
            managedObjectContext?.delete(price)
        }
    }
}

extension Product {
    /// The current price here, or nil if there isn't one or it isn't sold here.
    func latestPrice(at store: Store) -> Price? {
        latestSighting(at: store).flatMap { $0.isUnavailable ? nil : $0 }
    }

    /// The newest record here: a price, or a note that it isn't sold here.
    func latestSighting(at store: Store) -> Price? {
        (prices ?? []).filter { $0.store == store && !$0.isDeleted }.max(by: Price.isOlder)
    }

    func isUnavailable(at store: Store) -> Bool {
        latestSighting(at: store)?.isUnavailable == true
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
