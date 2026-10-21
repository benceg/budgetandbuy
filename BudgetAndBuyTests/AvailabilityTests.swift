import CoreData
import Testing
@testable import BudgetAndBuy

@MainActor
struct AvailabilityTests {
    let persistence = PersistenceController(inMemory: true)
    var household: Household { persistence.ensureHousehold() }

    @Test func markingNotSoldHidesThePrice() {
        let store = household.addStore()
        let milk = household.product(named: "Milk")
        store.recordPrice(145, for: milk, on: .now.addingTimeInterval(-60))
        #expect(!milk.isUnavailable(at: store))

        store.markUnavailable(milk)
        #expect(milk.isUnavailable(at: store))
        #expect(milk.latestPrice(at: store) == nil)
        #expect(store.currentPrices.isEmpty)
        #expect(store.unavailableProducts == [milk])

        store.markUnavailable(milk)
        #expect(store.prices?.count == 2, "Marking twice adds nothing")
    }

    @Test func soldHereAgainBringsBackTheLastPrice() {
        let store = household.addStore()
        let milk = household.product(named: "Milk")
        store.recordPrice(145, for: milk, on: .now.addingTimeInterval(-60))
        store.markUnavailable(milk)

        store.markAvailable(milk)
        #expect(!milk.isUnavailable(at: store))
        #expect(milk.latestPrice(at: store)?.amountMinor == 145)
    }

    @Test func aNewPriceMeansItIsSoldAgain() {
        let store = household.addStore()
        let milk = household.product(named: "Milk")
        store.markUnavailable(milk, on: .now.addingTimeInterval(-60))
        store.recordPrice(150, for: milk)
        #expect(!milk.isUnavailable(at: store))
        #expect(milk.latestPrice(at: store)?.amountMinor == 150)
    }

    @Test func comparisonsKnowWhatIsNotSoldAnywhere() throws {
        let aldi = household.addStore()
        let coop = household.addStore()
        let list = household.addList()
        let saffron = try #require(list.addItem(named: "Saffron"))
        let milk = try #require(list.addItem(named: "Milk"))
        let saffronProduct = try #require(saffron.product)
        aldi.markUnavailable(saffronProduct)
        coop.markUnavailable(saffronProduct)
        aldi.markUnavailable(try #require(milk.product))

        let comparison = StoreComparison(items: [saffron, milk], stores: [aldi, coop])
        #expect(comparison.notSoldAnywhere == [saffron])
        #expect(comparison.unavailableItems(at: aldi).count == 2)
        #expect(comparison.unavailableItems(at: coop) == [saffron])
        #expect(comparison.options.allSatisfy { $0.pricedCount == 0 })
    }

    @Test func movingAHouseholdKeepsWhatIsNotSold() throws {
        let store = household.addStore()
        store.name = "Aldi"
        store.markUnavailable(household.product(named: "Saffron"))

        let joined = Household.create(in: persistence.viewContext)
        household.moveContents(to: joined)
        let moved = try #require(joined.stores?.first)
        let saffron = try #require(joined.products?.first)
        #expect(saffron.isUnavailable(at: moved))
    }
}
