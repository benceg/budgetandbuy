import CoreData
import Foundation

/// Compares what a set of items costs at each of the household's stores.
///
/// Stores rarely have prices for everything, so every figure says which items
/// it covers, and savings are only claimed on items priced at both stores
/// being compared. Savings are measured against the nearest store: the one
/// you'd shop at if the trip were all that mattered.
struct StoreComparison {
    struct Option: Identifiable {
        let store: Store
        let totalMinor: Int64
        let pricedCount: Int
        let oldestPrice: Date?

        var id: NSManagedObjectID { store.objectID }
    }

    struct Saving {
        /// Positive when the store is cheaper than the nearest one.
        let amountMinor: Int64
        let commonCount: Int
        /// One way, compared with the nearest store.
        let extraMinutes: Int
    }

    /// Buying each item wherever it's cheaper across two stores.
    struct Split {
        let first: Store
        let second: Store
        let firstItems: [Item]
        let secondItems: [Item]
        let totalMinor: Int64

        var pricedCount: Int { firstItems.count + secondItems.count }
    }

    /// A split has to cover more items, or save at least this much, to be worth a second trip.
    static let minimumSplitSavingMinor: Int64 = 100

    let items: [Item]
    var itemCount: Int { items.count }
    /// Stores with prices for the most items first, then the cheapest.
    let options: [Option]
    let nearest: Store?
    let split: Split?
    /// Items with no price at any store.
    let unpriced: [Item]
    let stores: [Store]

    private let costs: [NSManagedObjectID: [NSManagedObjectID: Int64]]

    init(items: [Item], stores: [Store]) {
        self.items = items
        self.stores = stores

        var costs: [NSManagedObjectID: [NSManagedObjectID: Int64]] = [:]
        var options: [Option] = []
        for store in stores {
            let prices = Dictionary(
                store.currentPrices.compactMap { price in price.product.map { ($0.objectID, price) } },
                uniquingKeysWith: { first, _ in first }
            )
            var itemCosts: [NSManagedObjectID: Int64] = [:]
            var oldest: Date?
            for item in items {
                guard let productID = item.product?.objectID, let price = prices[productID] else { continue }
                itemCosts[item.objectID] = price.amountMinor * Int64(item.quantity)
                if let seen = price.createdAt, seen < (oldest ?? .distantFuture) { oldest = seen }
            }
            costs[store.objectID] = itemCosts
            options.append(Option(
                store: store,
                totalMinor: itemCosts.values.reduce(0, +),
                pricedCount: itemCosts.count,
                oldestPrice: oldest
            ))
        }
        self.costs = costs
        self.options = options.sorted { lhs, rhs in
            if lhs.pricedCount != rhs.pricedCount { return lhs.pricedCount > rhs.pricedCount }
            if lhs.totalMinor != rhs.totalMinor { return lhs.totalMinor < rhs.totalMinor }
            return (lhs.store.name ?? "").localizedStandardCompare(rhs.store.name ?? "") == .orderedAscending
        }

        nearest = stores.min {
            ($0.travelMinutes, $0.name ?? "") < ($1.travelMinutes, $1.name ?? "")
        }
        unpriced = items.filter { item in !costs.values.contains { $0[item.objectID] != nil } }
        split = Self.bestSplit(items: items, stores: stores, costs: costs, bestSingle: self.options.first)
    }

    /// How a store compares with the nearest one, on the items both have prices for.
    func saving(at store: Store) -> Saving? {
        guard let nearest, store != nearest,
              let theirs = costs[store.objectID], let nearestCosts = costs[nearest.objectID] else { return nil }
        let common = theirs.keys.filter { nearestCosts[$0] != nil }
        guard !common.isEmpty else { return nil }
        return Saving(
            amountMinor: common.reduce(0) { $0 + nearestCosts[$1]! - theirs[$1]! },
            commonCount: common.count,
            extraMinutes: Int(store.travelMinutes) - Int(nearest.travelMinutes)
        )
    }

    /// Items the store has been marked as not selling.
    func unavailableItems(at store: Store) -> [Item] {
        items.filter { $0.product?.isUnavailable(at: store) == true }
    }

    /// Items none of the stores sell, as opposed to ones nobody has priced yet.
    var notSoldAnywhere: [Item] {
        guard !stores.isEmpty else { return [] }
        return unpriced.filter { item in
            guard let product = item.product else { return false }
            return stores.allSatisfy { product.isUnavailable(at: $0) }
        }
    }

    /// The items with a price at a store.
    func pricedItems(at store: Store) -> [Item] {
        guard let storeCosts = costs[store.objectID] else { return [] }
        return items.filter { storeCosts[$0.objectID] != nil }
    }

    func option(for store: Store) -> Option? {
        options.first { $0.store == store }
    }

    /// The store that saves the most compared with the nearest one, if any does.
    var bestSaving: (option: Option, saving: Saving)? {
        options
            .compactMap { option in saving(at: option.store).map { (option, $0) } }
            .filter { $0.1.amountMinor > 0 }
            .max { $0.1.amountMinor < $1.1.amountMinor }
    }

    private static func bestSplit(
        items: [Item],
        stores: [Store],
        costs: [NSManagedObjectID: [NSManagedObjectID: Int64]],
        bestSingle: Option?
    ) -> Split? {
        var best: Split?
        for (index, first) in stores.enumerated() {
            for second in stores.dropFirst(index + 1) {
                var firstItems: [Item] = []
                var secondItems: [Item] = []
                var total: Int64 = 0
                for item in items {
                    let a = costs[first.objectID]?[item.objectID]
                    let b = costs[second.objectID]?[item.objectID]
                    if let a, a <= (b ?? .max) {
                        firstItems.append(item)
                        total += a
                    } else if let b {
                        secondItems.append(item)
                        total += b
                    }
                }
                guard !firstItems.isEmpty, !secondItems.isEmpty else { continue }
                // Lead with the store that takes most of the shop.
                let split = firstItems.count >= secondItems.count
                    ? Split(first: first, second: second, firstItems: firstItems, secondItems: secondItems, totalMinor: total)
                    : Split(first: second, second: first, firstItems: secondItems, secondItems: firstItems, totalMinor: total)
                if let current = best,
                   (current.pricedCount, -current.totalMinor) >= (split.pricedCount, -split.totalMinor) {
                    continue
                }
                best = split
            }
        }

        guard let best, let bestSingle else { return best }
        let coversMore = best.pricedCount > bestSingle.pricedCount
        let savesEnough = best.pricedCount == bestSingle.pricedCount
            && best.totalMinor + minimumSplitSavingMinor <= bestSingle.totalMinor
        return coversMore || savesEnough ? best : nil
    }
}
