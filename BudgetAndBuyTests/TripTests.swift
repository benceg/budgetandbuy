import CoreData
import Testing
@testable import BudgetAndBuy

@MainActor
struct TripTests {
    let persistence = PersistenceController(inMemory: true)
    let household: Household
    let coop: Store
    let aldi: Store
    let list: ShoppingList

    init() {
        household = persistence.ensureHousehold()
        coop = household.addStore()
        coop.name = "Co-op"
        coop.travel = .walk
        coop.travelMinutes = 4
        aldi = household.addStore()
        aldi.name = "Aldi"
        aldi.travel = .drive
        aldi.travelMinutes = 20
        aldi.distanceKm = 10
        list = household.addList()
        list.name = "Weekly"
        for (name, coopPrice, aldiPrice) in [("Milk", 175, 145), ("Bread", 250, 129)] {
            let item = list.addItem(named: name)!
            coop.recordPrice(Int64(coopPrice), for: item.product!)
            aldi.recordPrice(Int64(aldiPrice), for: item.product!)
            item.setChecked(true)
        }
        list.addItem(named: "Saffron")?.setChecked(true)
        list.addItem(named: "Eggs")
    }

    @Test func shoppingFurtherAwayIsComparedWithTheNearest() throws {
        let trip = try #require(list.finishShopping(at: aldi, stores: [aldi, coop]))
        #expect(trip.storeName == "Aldi")
        #expect(trip.listName == "Weekly")
        #expect(trip.spentMinor == 145 + 129)
        #expect(trip.pricedCount == 2)
        #expect(trip.itemCount == 3)
        #expect(trip.comparedStoreName == "Co-op")
        #expect(trip.savedMinor == (175 + 250) - (145 + 129))
        #expect(trip.household == household)
    }

    @Test func shoppingLocallyIsComparedWithTheCheapest() throws {
        let trip = try #require(list.finishShopping(at: coop, stores: [aldi, coop]))
        #expect(trip.spentMinor == 175 + 250)
        #expect(trip.comparedStoreName == "Aldi")
        #expect(trip.savedMinor == -((175 + 250) - (145 + 129)))
    }

    @Test func finishingClearsOnlyTheBasket() throws {
        list.finishShopping(at: aldi, stores: [aldi, coop])
        try persistence.viewContext.save()
        #expect(list.items?.map(\.displayName) == ["Eggs"])
    }

    @Test func nothingToFinishWithAnEmptyBasket() {
        for item in list.basket { item.setChecked(false) }
        #expect(list.finishShopping(at: aldi, stores: [aldi, coop]) == nil)
    }

    @Test func statsAddUpSavingsWithinThePeriod() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let far = try #require(list.finishShopping(at: aldi, stores: [aldi, coop]))
        far.createdAt = now
        for item in list.items ?? [] { item.setChecked(true) }
        list.addItem(named: "Milk")?.setChecked(true)
        list.addItem(named: "Bread")?.setChecked(true)
        let local = try #require(list.finishShopping(at: coop, stores: [aldi, coop]))
        local.createdAt = Calendar.current.date(byAdding: .year, value: -2, to: now)

        let allTime = TripStats(trips: [far, local], period: .allTime, now: now)
        #expect(allTime.trips == [far, local])
        #expect(allTime.savedMinor == far.savedMinor)
        #expect(allTime.spentMinor == far.spentMinor + local.spentMinor)
        #expect(allTime.stores.map(\.name) == ["Aldi", "Co-op"])

        let thisYear = TripStats(trips: [far, local], period: .year, now: now)
        #expect(thisYear.trips == [far])
    }

    @Test func movingContentsCopiesTrips() throws {
        let trip = try #require(list.finishShopping(at: aldi, stores: [aldi, coop]))
        let joined = Household.create(in: persistence.viewContext)
        household.moveContents(to: joined)
        try persistence.viewContext.save()

        #expect(trip.isDeleted || trip.managedObjectContext == nil)
        let moved = try #require(joined.trips?.first)
        #expect(moved.storeName == "Aldi")
        #expect(moved.savedMinor == (175 + 250) - (145 + 129))
        #expect(moved.store?.household == joined)
    }
}
