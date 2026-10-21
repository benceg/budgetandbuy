import CoreData
import Testing
@testable import BudgetAndBuy

@MainActor
struct HouseholdTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    @Test func theFirstHouseholdIsAStarterCalledHome() {
        let home = persistence.ensureHousehold()
        #expect(home.isStarter)
        #expect(home.name == "Home")
        #expect(persistence.ensureHousehold() == home)
    }

    @Test func householdsYouMakeAreNeverMerged() throws {
        let home = persistence.ensureHousehold()
        home.addList().name = "Weekly"
        let granny = persistence.createHousehold(named: "Granny’s House", colorName: "orchid")
        granny.addList().name = "Granny’s Weekly"
        #expect(!granny.isStarter)
        try context.save()

        try context.mergeDuplicateHouseholds()
        let households = try context.fetch(NSFetchRequest<Household>(entityName: "Household"))
        #expect(Set(households) == [home, granny])
        #expect(granny.lists?.count == 1)
    }

    @Test func anEmptyStarterGoesOnceOtherHouseholdsArrive() throws {
        // A new device makes a starter before iCloud delivers the households
        // made elsewhere, before starters existed.
        let starter = persistence.ensureHousehold()
        let existing = Household.create(in: context)
        existing.addList().name = "Weekly"
        try context.save()

        try context.mergeDuplicateHouseholds()
        let households = try context.fetch(NSFetchRequest<Household>(entityName: "Household"))
        #expect(households == [existing])
        #expect(starter.isDeleted || starter.managedObjectContext == nil)
    }

    @Test func aStarterInUseIsKept() throws {
        let starter = persistence.ensureHousehold()
        starter.addList().name = "Weekly"
        let other = persistence.createHousehold(named: "Granny’s House")
        try context.save()

        try context.mergeDuplicateHouseholds()
        let households = try context.fetch(NSFetchRequest<Household>(entityName: "Household"))
        #expect(Set(households) == [starter, other])
    }

    @Test func copyingShopsCanBringPricesAndWhatIsNotSold() throws {
        let home = persistence.ensureHousehold()
        let aldi = home.addStore()
        aldi.name = "Aldi"
        aldi.travel = .walk
        aldi.travelMinutes = 7
        let milk = home.product(named: "Milk", size: ProductSize(amount: 2, unit: .litres))
        milk.category = .dairyAndEggs
        aldi.recordPrice(145, for: milk, on: .now.addingTimeInterval(-86_400))
        aldi.markUnavailable(home.product(named: "Saffron"))
        home.addList().addItem(named: "Bread")

        let withPrices = persistence.createHousehold(named: "Granny’s House")
        withPrices.copyShops(from: home, includingPrices: true)
        let copiedAldi = try #require(withPrices.stores?.first)
        #expect(copiedAldi.name == "Aldi")
        #expect(copiedAldi.travel == .walk)
        #expect(copiedAldi.travelMinutes == 7)
        let copiedMilk = try #require(withPrices.products?.first { $0.name == "Milk" })
        #expect(copiedMilk.size == ProductSize(amount: 2, unit: .litres))
        #expect(copiedMilk.category == .dairyAndEggs)
        #expect(copiedMilk.latestPrice(at: copiedAldi)?.amountMinor == 145)
        let copiedSaffron = try #require(withPrices.products?.first { $0.name == "Saffron" })
        #expect(copiedSaffron.isUnavailable(at: copiedAldi))
        #expect(withPrices.lists?.isEmpty ?? true, "Lists aren’t copied")
        #expect(home.stores?.count == 1, "The original keeps its shops")

        let withoutPrices = persistence.createHousehold(named: "Holiday")
        withoutPrices.copyShops(from: home, includingPrices: false)
        #expect(withoutPrices.stores?.count == 1)
        #expect(withoutPrices.products?.isEmpty ?? true)
        #expect(withoutPrices.stores?.first?.prices?.isEmpty ?? true)
    }

    @Test func homeListsHouseholdsAlphabetically() {
        let home = persistence.ensureHousehold()
        let granny = persistence.createHousehold(named: "Granny’s House")
        let allotment = persistence.createHousehold(named: "allotment")
        #expect(HouseholdSelection.sorted([home, granny, allotment]) == [allotment, granny, home])
    }

    @Test func theCurrentHouseholdFallsBackToYourOwn() {
        let home = persistence.ensureHousehold()
        let granny = persistence.createHousehold(named: "Granny’s House")
        let grannyID = granny.uuid?.uuidString ?? ""
        #expect(HouseholdSelection.preferred(from: [home, granny], selectedID: grannyID) == granny)
        #expect(HouseholdSelection.preferred(from: [home, granny], selectedID: "gone") == home)
    }
}
