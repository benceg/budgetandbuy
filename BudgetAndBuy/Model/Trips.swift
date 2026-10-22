import CoreData
import Foundation

extension ShoppingList {
    /// Records a trip for everything in the basket, bought at `store`, then
    /// clears the basket, with what it saved against `stores`' prices.
    @discardableResult
    func finishShopping(at store: Store, stores: [Store]) -> Trip? {
        let bought = basket
        guard !bought.isEmpty, let household, let context = managedObjectContext else { return nil }

        let total = StoreTotal(items: bought, at: store)
        let savings = Savings(items: bought, at: store, comparedWith: stores)

        let trip = household.insertRelated(Trip.self)
        trip.household = household
        trip.store = store
        trip.storeName = store.name
        trip.listName = name
        trip.spentMinor = total.amountMinor
        trip.itemCount = Int16(clamping: total.itemCount)
        trip.pricedCount = Int16(clamping: total.pricedCount)
        trip.savings = savings

        for item in bought {
            context.delete(item)
        }
        return trip
    }
}

/// What compared items saved, against each way of pricing them at your
/// other shops: positive when they cost less here.
struct Savings: Equatable {
    /// What prices at your other shops are compared with.
    enum Basis: String, CaseIterable, Identifiable {
        case cheapest, average, dearest

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .cheapest: "Cheapest"
            case .average: "Average"
            case .dearest: "Dearest"
            }
        }
    }

    var comparedCount = 0
    var cheapestMinor: Int64 = 0
    var averageMinor: Int64 = 0
    var dearestMinor: Int64 = 0

    subscript(basis: Basis) -> Int64 {
        switch basis {
        case .cheapest: cheapestMinor
        case .average: averageMinor
        case .dearest: dearestMinor
        }
    }

    init() {}

    /// Each item's price at `store`, against the latest prices for the same
    /// product at the other stores. Items with no price here, or none at
    /// any other store, aren't compared.
    init(items: some Sequence<Item>, at store: Store, comparedWith stores: some Sequence<Store>) {
        let others = stores.filter { $0 != store }
        var average = 0.0
        for item in items {
            guard let product = item.product, let paid = product.latestPrice(at: store)?.amountMinor else { continue }
            let elsewhere = others.compactMap { product.latestPrice(at: $0)?.amountMinor }
            guard let lowest = elsewhere.min(), let highest = elsewhere.max() else { continue }
            let quantity = Int64(item.quantity)
            comparedCount += 1
            cheapestMinor += (lowest - paid) * quantity
            dearestMinor += (highest - paid) * quantity
            average += (Double(elsewhere.reduce(0, +)) / Double(elsewhere.count) - Double(paid)) * Double(quantity)
        }
        averageMinor = Int64(average.rounded())
    }

    static func + (lhs: Savings, rhs: Savings) -> Savings {
        var sum = lhs
        sum.comparedCount += rhs.comparedCount
        sum.cheapestMinor += rhs.cheapestMinor
        sum.averageMinor += rhs.averageMinor
        sum.dearestMinor += rhs.dearestMinor
        return sum
    }
}

extension Trip {
    var savings: Savings {
        get {
            var savings = Savings()
            savings.comparedCount = Int(comparedCount)
            savings.cheapestMinor = savedVsCheapestMinor
            savings.averageMinor = savedVsAverageMinor
            savings.dearestMinor = savedVsDearestMinor
            return savings
        }
        set {
            comparedCount = Int16(clamping: newValue.comparedCount)
            savedVsCheapestMinor = newValue.cheapestMinor
            savedVsAverageMinor = newValue.averageMinor
            savedVsDearestMinor = newValue.dearestMinor
        }
    }
}

/// Totals over a household's trips.
struct TripStats {
    enum Period: String, CaseIterable, Identifiable {
        case month, year, allTime

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .month: "This Month"
            case .year: "This Year"
            case .allTime: "All Time"
            }
        }

        func start(relativeTo now: Date, calendar: Calendar = .current) -> Date? {
            switch self {
            case .month: calendar.dateInterval(of: .month, for: now)?.start
            case .year: calendar.dateInterval(of: .year, for: now)?.start
            case .allTime: nil
            }
        }
    }

    struct StoreSummary: Identifiable {
        let name: String
        let tripCount: Int
        let spentMinor: Int64
        let savings: Savings

        var id: String { name }
    }

    let trips: [Trip]
    let spentMinor: Int64
    /// What shopping where you did saved, less what it cost extra.
    let savings: Savings
    let stores: [StoreSummary]

    init(trips: some Sequence<Trip>, period: Period, now: Date = .now) {
        let start = period.start(relativeTo: now)
        let trips = trips
            .filter { trip in start.map { (trip.createdAt ?? .distantPast) >= $0 } ?? true }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        self.trips = trips
        spentMinor = trips.reduce(0) { $0 + $1.spentMinor }
        savings = trips.reduce(Savings()) { $0 + $1.savings }
        stores = Dictionary(grouping: trips) { $0.storeName ?? "" }
            .map { name, trips in
                StoreSummary(
                    name: name,
                    tripCount: trips.count,
                    spentMinor: trips.reduce(0) { $0 + $1.spentMinor },
                    savings: trips.reduce(Savings()) { $0 + $1.savings }
                )
            }
            .sorted { ($0.tripCount, $1.name) > ($1.tripCount, $0.name) }
    }
}
