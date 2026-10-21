import CoreData
import Testing
@testable import BudgetAndBuy

@MainActor
struct ExampleDataTests {
    let persistence = PersistenceController(inMemory: true)
    var household: Household { persistence.ensureHousehold() }

    private func store(_ shop: ExampleData.Shop) throws -> Store {
        try #require(household.stores?.first { $0.name == shop.name })
    }

    private func product(_ name: String) throws -> Product {
        let (name, size) = ProductSize.split(name)
        return try #require(household.products?.first { $0.matches(normalizedName: ProductName.normalized(name), size: size) })
    }

    @Test func loadsShopsPricesAndAList() throws {
        ExampleData.load(into: household)
        #expect(household.stores?.count == 4)
        let list = try #require(household.lists?.first { $0.name == "Example Weekly Shop" })
        #expect(list.items?.count == 17)
        #expect(list.items?.allSatisfy { $0.product?.category != nil } == true)
    }

    @Test func shopsDifferInPriceAndRange() throws {
        ExampleData.load(into: household)
        let milk = try product("Semi-skimmed milk 4 pints")
        let prices = try ExampleData.shops.map { try #require(milk.latestPrice(at: store($0))?.amountMinor) }
        // Aldi, Sainsbury's, Tesco Express, Waitrose: cheapest to dearest.
        #expect(prices == prices.sorted())

        let ranges = try ExampleData.shops.map { try store($0).currentPrices.count }
        #expect(ranges[1] > ranges[0] && ranges[0] > ranges[3] && ranges[3] > ranges[2])

        let ice = try product("Ben & Jerry’s ice cream 465ml")
        #expect(ice.prices?.compactMap(\.store?.name) == [ExampleData.tesco.name])
        let sourdough = try product("Duchy Organic sourdough 800g")
        #expect(sourdough.prices?.compactMap(\.store?.name) == [ExampleData.waitrose.name])
    }

    @Test func loadingTwiceDuplicatesNothing() throws {
        ExampleData.load(into: household)
        let products = household.products?.count
        ExampleData.load(into: household)
        #expect(household.stores?.count == 4)
        #expect(household.products?.count == products)
        #expect(household.lists?.count == 1)
        #expect(household.lists?.first?.items?.count == 17)
    }

    @Test func noShopCoversTheWholeList() throws {
        ExampleData.load(into: household)
        let list = try #require(household.lists?.first)
        let comparison = StoreComparison(items: Array(list.items ?? []), stores: Array(household.stores ?? []))
        #expect(comparison.options.allSatisfy { $0.pricedCount < comparison.itemCount })
        #expect(comparison.split != nil)
    }
}
