import CoreData
import Foundation

/// A way to shop a list: which stores to visit and what to buy at each.
struct ShoppingPlan {
    enum Goal: String, CaseIterable, Identifiable {
        case cheapest, fewestStops, closest

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .cheapest: "Cheapest"
            case .fewestStops: "One Stop"
            case .closest: "Closest"
            }
        }
    }

    struct Stop: Identifiable {
        let store: Store
        let items: [Item]
        let totalMinor: Int64

        var id: NSManagedObjectID { store.objectID }
    }

    let goal: Goal
    let stops: [Stop]
    let itemCount: Int

    var totalMinor: Int64 { stops.reduce(0) { $0 + $1.totalMinor } }
    var pricedCount: Int { stops.reduce(0) { $0 + $1.items.count } }

    /// One-way journey time to every stop, added up.
    var travelMinutes: Int { stops.reduce(0) { $0 + Int($1.store.travelMinutes) } }

    /// The plan for a goal, or nil when no store has a price for anything.
    init?(goal: Goal, comparison: StoreComparison) {
        var stops: [Stop] = []
        if goal == .cheapest, let split = comparison.split {
            stops = [
                Stop(store: split.first, items: split.firstItems, totalMinor: Self.total(of: split.firstItems, at: split.first)),
                Stop(store: split.second, items: split.secondItems, totalMinor: Self.total(of: split.secondItems, at: split.second)),
            ]
        } else if let store = goal == .closest ? comparison.nearest : comparison.options.first?.store {
            stops = [Stop(store: store, items: comparison.pricedItems(at: store), totalMinor: comparison.option(for: store)?.totalMinor ?? 0)]
        }
        guard stops.contains(where: { !$0.items.isEmpty }) else { return nil }
        self.goal = goal
        self.stops = stops
        itemCount = comparison.itemCount
    }

    private static func total(of items: [Item], at store: Store) -> Int64 {
        StoreTotal(items: items, at: store).amountMinor
    }
}

/// What a list is likely to cost, by aisle, for budgeting.
///
/// Each item is priced at the store you're shopping in if it has a price there,
/// otherwise at the lowest price seen anywhere.
struct ListEstimate {
    struct Aisle: Identifiable {
        let category: ProductCategory
        let totalMinor: Int64
        let itemCount: Int

        var id: ProductCategory { category }
    }

    let totalMinor: Int64
    let pricedCount: Int
    let itemCount: Int
    /// Most expensive first.
    let aisles: [Aisle]

    init(items: [Item], stores: [Store], preferring preferred: Store? = nil) {
        var totals: [ProductCategory: (minor: Int64, count: Int)] = [:]
        var total: Int64 = 0
        var priced = 0
        for item in items {
            guard let product = item.product, let unit = Self.price(of: product, stores: stores, preferring: preferred) else { continue }
            let cost = unit * Int64(item.quantity)
            let category = product.category ?? .other
            totals[category, default: (0, 0)].minor += cost
            totals[category, default: (0, 0)].count += 1
            total += cost
            priced += 1
        }
        totalMinor = total
        pricedCount = priced
        itemCount = items.count
        aisles = totals
            .map { Aisle(category: $0.key, totalMinor: $0.value.minor, itemCount: $0.value.count) }
            .sorted { ($0.totalMinor, $1.category.rawValue) > ($1.totalMinor, $0.category.rawValue) }
    }

    private static func price(of product: Product, stores: [Store], preferring preferred: Store?) -> Int64? {
        if let preferred, let price = product.latestPrice(at: preferred) {
            return price.amountMinor
        }
        return stores.compactMap { product.latestPrice(at: $0)?.amountMinor }.min()
    }
}

/// How a budget is going.
struct BudgetProgress {
    let spentMinor: Int64
    let budgetMinor: Int64

    var fraction: Double { budgetMinor > 0 ? Double(spentMinor) / Double(budgetMinor) : 0 }
    var remainingMinor: Int64 { budgetMinor - spentMinor }
    var isOver: Bool { budgetMinor > 0 && spentMinor > budgetMinor }
}
