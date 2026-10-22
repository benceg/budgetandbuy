import CoreData
import Testing
@testable import BudgetAndBuy

@MainActor
struct TripTests {
    let persistence = PersistenceController(inMemory: true)
    let household: Household
    let coop: Store
    let aldi: Store
    let waitrose: Store
    let list: ShoppingList

    init() {
        household = persistence.ensureHousehold()
        coop = household.addStore()
        coop.name = "Co-op"
        aldi = household.addStore()
        aldi.name = "Aldi"
        waitrose = household.addStore()
        waitrose.name = "Waitrose"
        list = household.addList()
        list.name = "Weekly"
        for (name, coopPrice, aldiPrice, waitrosePrice) in [("Milk", 175, 145, 199), ("Bread", 250, 129, 300)] {
            let item = list.addItem(named: name)!
            coop.recordPrice(Int64(coopPrice), for: item.product!)
            aldi.recordPrice(Int64(aldiPrice), for: item.product!)
            waitrose.recordPrice(Int64(waitrosePrice), for: item.product!)
            item.setChecked(true)
        }
        list.addItem(named: "Saffron")?.setChecked(true)
        list.addItem(named: "Eggs")
    }

    private var stores: [Store] { [aldi, coop, waitrose] }

    @Test func recordsWhatTheTripCost() throws {
        let trip = try #require(list.finishShopping(at: aldi, stores: stores))
        #expect(trip.storeName == "Aldi")
        #expect(trip.listName == "Weekly")
        #expect(trip.spentMinor == 145 + 129)
        #expect(trip.pricedCount == 2)
        #expect(trip.itemCount == 3)
        #expect(trip.household == household)
    }

    @Test func shoppingCheaplySavesAgainstEveryComparison() throws {
        let trip = try #require(list.finishShopping(at: aldi, stores: stores))
        let savings = trip.savings
        // Saffron has no price anywhere, so only milk and bread are compared.
        #expect(savings.comparedCount == 2)
        #expect(savings[.cheapest] == (175 - 145) + (250 - 129))
        #expect(savings[.average] == (187 - 145) + (275 - 129))
        #expect(savings[.dearest] == (199 - 145) + (300 - 129))
    }

    @Test func convenienceCostsExtraAgainstTheCheapest() throws {
        let trip = try #require(list.finishShopping(at: coop, stores: stores))
        let savings = trip.savings
        #expect(savings[.cheapest] == (145 - 175) + (129 - 250))
        // 172 - 175 for milk, and 214.5 - 250 for bread.
        #expect(savings[.average] == -39)
        #expect(savings[.dearest] == (199 - 175) + (300 - 250))
    }

    @Test func savingsCountQuantities() throws {
        list.items?.first { $0.displayName == "Milk" }?.quantity = 3
        let trip = try #require(list.finishShopping(at: aldi, stores: stores))
        #expect(trip.savings[.cheapest] == (175 - 145) * 3 + (250 - 129))
    }

    @Test func onlyOtherShopsWithPricesAreCompared() throws {
        let milk = try #require(list.items?.first { $0.displayName == "Milk" }?.product)
        waitrose.markUnavailable(milk)
        let trip = try #require(list.finishShopping(at: aldi, stores: [aldi, waitrose]))
        // Waitrose doesn't sell milk any more, so only bread is compared.
        #expect(trip.comparedCount == 1)
        #expect(trip.savings[.cheapest] == 300 - 129)
        #expect(trip.savings[.dearest] == 300 - 129)
    }

    @Test func nothingToCompareWithOneShop() throws {
        let trip = try #require(list.finishShopping(at: aldi, stores: [aldi]))
        #expect(trip.savings == Savings())
    }

    @Test func finishingClearsOnlyTheBasket() throws {
        list.finishShopping(at: aldi, stores: stores)
        try persistence.viewContext.save()
        #expect(list.items?.map(\.displayName) == ["Eggs"])
    }

    @Test func nothingToFinishWithAnEmptyBasket() {
        for item in list.basket { item.setChecked(false) }
        #expect(list.finishShopping(at: aldi, stores: stores) == nil)
    }

    @Test func statsAddUpSavingsAndExtrasWithinThePeriod() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cheap = try #require(list.finishShopping(at: aldi, stores: stores))
        cheap.createdAt = now
        list.addItem(named: "Milk")?.setChecked(true)
        list.addItem(named: "Bread")?.setChecked(true)
        let dear = try #require(list.finishShopping(at: coop, stores: stores))
        dear.createdAt = Calendar.current.date(byAdding: .year, value: -2, to: now)

        let allTime = TripStats(trips: [cheap, dear], period: .allTime, now: now)
        #expect(allTime.trips == [cheap, dear])
        #expect(allTime.savings[.cheapest] == cheap.savedVsCheapestMinor + dear.savedVsCheapestMinor)
        #expect(allTime.savings[.cheapest] == 0)
        #expect(allTime.savings.comparedCount == 4)
        #expect(allTime.spentMinor == cheap.spentMinor + dear.spentMinor)
        #expect(allTime.stores.map(\.name) == ["Aldi", "Co-op"])
        #expect(allTime.stores.first?.savings == cheap.savings)

        let thisYear = TripStats(trips: [cheap, dear], period: .year, now: now)
        #expect(thisYear.trips == [cheap])
        #expect(thisYear.savings == cheap.savings)
    }

    @Test func movingContentsCopiesTrips() throws {
        let trip = try #require(list.finishShopping(at: aldi, stores: stores))
        let savings = trip.savings
        let joined = Household.create(in: persistence.viewContext)
        household.moveContents(to: joined)
        try persistence.viewContext.save()

        #expect(trip.isDeleted || trip.managedObjectContext == nil)
        let moved = try #require(joined.trips?.first)
        #expect(moved.storeName == "Aldi")
        #expect(moved.savings == savings)
        #expect(moved.store?.household == joined)
    }
}
