import CoreData
import Foundation

extension ShoppingList {
    /// Records a trip for everything in the basket, bought at `store`, then
    /// clears the basket.
    ///
    /// Each trip is weighed against an alternative so that both kinds of good
    /// choice count. Shopping further afield is compared with the nearest
    /// store: money saved, carbon spent. Shopping at the nearest store is
    /// compared with the store that would have been cheapest: carbon avoided,
    /// money spent.
    @discardableResult
    func finishShopping(at store: Store, stores: [Store]) -> Trip? {
        let bought = basket
        guard !bought.isEmpty, let household, let context = managedObjectContext else { return nil }

        let comparison = StoreComparison(items: bought, stores: stores)
        let total = StoreTotal(items: bought, at: store)

        let trip = household.insertRelated(Trip.self)
        trip.household = household
        trip.store = store
        trip.storeName = store.name
        trip.listName = name
        trip.travelMode = store.travelMode
        trip.spentMinor = total.amountMinor
        trip.itemCount = Int16(clamping: total.itemCount)
        trip.pricedCount = Int16(clamping: total.pricedCount)
        trip.carbonKg = store.roundTripCarbonKg ?? 0

        if let nearest = comparison.nearest, store != nearest {
            trip.comparedStoreName = nearest.name
            trip.savedMinor = comparison.saving(at: store)?.amountMinor ?? 0
            trip.carbonSavedKg = -(comparison.extraCarbonKg(at: store) ?? 0)
        } else if let alternative = comparison.bestSaving {
            trip.comparedStoreName = alternative.option.store.name
            trip.savedMinor = -alternative.saving.amountMinor
            trip.carbonSavedKg = comparison.extraCarbonKg(at: alternative.option.store) ?? 0
        }

        for item in bought {
            context.delete(item)
        }
        return trip
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
        let savedMinor: Int64

        var id: String { name }
    }

    let trips: [Trip]
    let spentMinor: Int64
    /// Money saved by shopping around. Trips that cost more aren't subtracted:
    /// they're counted for the carbon they saved instead.
    let savedMinor: Int64
    /// Carbon avoided by shopping closer to home.
    let carbonAvoidedKg: Double
    let carbonKg: Double
    let stores: [StoreSummary]

    init(trips: some Sequence<Trip>, period: Period, now: Date = .now) {
        let start = period.start(relativeTo: now)
        let trips = trips
            .filter { trip in start.map { (trip.createdAt ?? .distantPast) >= $0 } ?? true }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        self.trips = trips
        spentMinor = trips.reduce(0) { $0 + $1.spentMinor }
        savedMinor = trips.reduce(0) { $0 + max(0, $1.savedMinor) }
        carbonAvoidedKg = trips.reduce(0) { $0 + max(0, $1.carbonSavedKg) }
        carbonKg = trips.reduce(0) { $0 + $1.carbonKg }
        stores = Dictionary(grouping: trips) { $0.storeName ?? "" }
            .map { name, trips in
                StoreSummary(
                    name: name,
                    tripCount: trips.count,
                    spentMinor: trips.reduce(0) { $0 + $1.spentMinor },
                    savedMinor: trips.reduce(0) { $0 + max(0, $1.savedMinor) }
                )
            }
            .sorted { ($0.tripCount, $1.name) > ($1.tripCount, $0.name) }
    }
}

extension Trip {
    var travel: TravelMode { travelMode.flatMap(TravelMode.init(rawValue:)) ?? .drive }
}
