import CoreData
import CoreLocation
import Testing
@testable import BudgetAndBuy

@MainActor
struct StoreComparisonTests {
    let persistence = PersistenceController(inMemory: true)
    let household: Household
    let coop: Store
    let aldi: Store
    let list: ShoppingList
    /// Round the corner from the Co-op, and a drive from Aldi.
    let here = CLLocation(latitude: 51.501, longitude: -0.1)

    init() {
        household = persistence.ensureHousehold()
        coop = household.addStore()
        coop.name = "Co-op"
        coop.latitude = 51.5
        coop.longitude = -0.1
        aldi = household.addStore()
        aldi.name = "Aldi"
        aldi.latitude = 51.6
        aldi.longitude = -0.1
        list = household.addList()
    }

    private func item(_ name: String, quantity: Int16 = 1, coop coopPrice: Int64? = nil, aldi aldiPrice: Int64? = nil) -> Item {
        let item = list.addItem(named: name)!
        item.quantity = quantity
        if let coopPrice { coop.recordPrice(coopPrice, for: item.product!) }
        if let aldiPrice { aldi.recordPrice(aldiPrice, for: item.product!) }
        return item
    }

    @Test func comparesAgainstTheNearestStoreOnItemsBothHavePriced() throws {
        let items = [
            item("Milk", quantity: 2, coop: 175, aldi: 145),
            item("Bread", coop: 250, aldi: 129),
            item("Saffron", coop: 300),
        ]
        let comparison = StoreComparison(items: items, stores: [aldi, coop], origin: here)

        #expect(comparison.nearest == coop)
        #expect(comparison.options.map(\.store) == [coop, aldi])
        let coopTotal: Int64 = 175 * 2 + 250 + 300
        let aldiTotal: Int64 = 145 * 2 + 129
        #expect(comparison.options.map(\.totalMinor) == [coopTotal, aldiTotal])
        #expect(comparison.options.map(\.pricedCount) == [3, 2])
        #expect(comparison.saving(at: coop) == nil)

        let saving = try #require(comparison.saving(at: aldi))
        let coopOnCommonItems: Int64 = 175 * 2 + 250
        #expect(saving.amountMinor == coopOnCommonItems - aldiTotal)
        #expect(saving.commonCount == 2)
        #expect(comparison.bestSaving?.option.store == aldi)
    }

    @Test func nearestIsWhereverYouAre() {
        let byAldi = CLLocation(latitude: 51.599, longitude: -0.1)
        #expect(StoreComparison(items: [], stores: [aldi, coop], origin: byAldi).nearest == aldi)
    }

    @Test func noNearestStoreOrSavingsWithoutYourLocation() {
        let items = [item("Milk", coop: 175, aldi: 145)]
        let comparison = StoreComparison(items: items, stores: [aldi, coop])
        #expect(comparison.nearest == nil)
        #expect(comparison.saving(at: aldi) == nil)
        #expect(comparison.bestSaving == nil)
        // What things cost still works.
        #expect(comparison.options.first?.store == aldi)
    }

    @Test func splitsTheShopWhenTwoStoresBeatOne() throws {
        let milk = item("Milk", coop: 175, aldi: 145)
        let bread = item("Bread", coop: 250, aldi: 129)
        let saffron = item("Saffron", coop: 300)
        let comparison = StoreComparison(items: [milk, bread, saffron], stores: [aldi, coop])

        let split = try #require(comparison.split)
        #expect(split.first == aldi)
        #expect(split.firstItems == [milk, bread])
        #expect(split.second == coop)
        #expect(split.secondItems == [saffron])
        #expect(split.totalMinor == 145 + 129 + 300)
    }

    @Test func skipsSplittingWhenOneStoreIsCheapestForEverything() {
        let items = [item("Milk", coop: 175, aldi: 145), item("Bread", coop: 250, aldi: 129)]
        let comparison = StoreComparison(items: items, stores: [aldi, coop])
        #expect(comparison.split == nil)
    }

    @Test func skipsSplittingForSmallSavings() {
        // Splitting would save 50p, under the threshold for a second trip.
        let items = [item("Milk", coop: 150, aldi: 100), item("Bread", coop: 100, aldi: 200)]
        let single = StoreComparison(items: items, stores: [aldi, coop])
        #expect(single.options.first?.totalMinor == 250)
        #expect(single.split == nil)
    }

    @Test func listsItemsWithNoPriceAnywhere() {
        let milk = item("Milk", coop: 175)
        let unicorn = item("Unicorn")
        let comparison = StoreComparison(items: [milk, unicorn], stores: [aldi, coop])
        #expect(comparison.unpriced == [unicorn])
    }

    @Test func noSavingWhenNothingIsCheaper() {
        let items = [item("Milk", coop: 145, aldi: 175)]
        let comparison = StoreComparison(items: items, stores: [aldi, coop], origin: here)
        #expect(comparison.saving(at: aldi)?.amountMinor == -30)
        #expect(comparison.bestSaving == nil)
    }
}
