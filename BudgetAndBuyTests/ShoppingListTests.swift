import CoreData
import CoreLocation
import Testing
import UIKit
@testable import BudgetAndBuy

@MainActor
struct ShoppingListTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }
    var household: Household { persistence.ensureHousehold() }

    @Test func normalisesProductNames() {
        #expect(ProductName.display("  oat   milk ") == "oat milk")
        #expect(ProductName.normalized("  Semi-Skimmed   MILK ") == "semi-skimmed milk")
        #expect(ProductName.normalized("Crème Fraîche") == "creme fraiche")
    }

    @Test func ignoresBlankItems() {
        let list = household.addList()
        #expect(list.addItem(named: "   ") == nil)
        #expect(list.items?.isEmpty ?? true)
    }

    @Test func addingAnItemTwiceIncreasesItsQuantity() throws {
        let list = household.addList()
        let first = try #require(list.addItem(named: "Milk"))
        let second = try #require(list.addItem(named: " milk "))
        #expect(first == second)
        #expect(first.quantity == 2)
        #expect(list.items?.count == 1)
    }

    @Test func addingABasketItemPutsItBackOnTheList() throws {
        let list = household.addList()
        let item = try #require(list.addItem(named: "Bread"))
        item.quantity = 3
        item.setChecked(true)

        list.addItem(named: "bread")
        #expect(!item.isChecked)
        #expect(item.checkedAt == nil)
        #expect(item.quantity == 1)
    }

    @Test func untickingPutsAnItemBackInItsAisle() throws {
        let list = household.addList()
        let milk = try #require(list.addItem(named: "Milk"))
        try context.save()
        let toBuy = NSFetchRequest<Item>(entityName: "Item")
        toBuy.predicate = NSPredicate(format: "list == %@ AND isChecked == NO", list)

        milk.setChecked(true)
        try context.save()
        #expect(try context.fetch(toBuy).isEmpty)

        milk.setChecked(false)
        try context.save()
        #expect(try context.fetch(toBuy) == [milk])
        #expect(milk.checkedAt == nil)
        #expect(ProductCategory.aisles(of: [milk]).map(\.category) == [.dairyAndEggs])
    }

    @Test func listsInAHouseholdShareProducts() throws {
        let weekly = household.addList()
        let party = household.addList()
        let eggs = try #require(weekly.addItem(named: "Eggs"))
        let moreEggs = try #require(party.addItem(named: "EGGS"))
        #expect(eggs.product == moreEggs.product)
        #expect(household.products?.count == 1)
    }

    @Test func suggestsPrefixMatchesFirst() {
        _ = household.product(named: "Oat milk")
        _ = household.product(named: "Milk chocolate")
        _ = household.product(named: "Bread")
        let names = household.products(matching: "milk", limit: 5).map(\.name)
        #expect(names == ["Milk chocolate", "Oat milk"])
    }

    @Test func mergesHouseholdsCreatedOnTwoDevices() throws {
        let original = household
        let originalBread = original.product(named: "Bread")
        try context.save()

        let duplicate = Household.create(in: context)
        duplicate.createdAt = try #require(original.createdAt).addingTimeInterval(60)
        let list = duplicate.addList()
        let toast = try #require(list.addItem(named: "bread"))
        let duplicateBread = try #require(toast.product)
        duplicateBread.category = .bakery
        list.add(original.product(named: "Bread"))

        try context.mergeDuplicateHouseholds()

        let households = try context.fetch(NSFetchRequest<Household>(entityName: "Household"))
        #expect(households == [original])
        #expect(list.household == original)
        #expect(original.products == [originalBread])
        #expect(originalBread.category == .bakery)
        #expect(list.items?.count == 1)
        #expect(list.items?.first?.product == originalBread)
    }

    @Test func movingContentsCopiesListsIntoAnotherHousehold() throws {
        let mine = household
        let weekly = mine.addList()
        weekly.name = "Weekly"
        weekly.colorName = "orange"
        let milk = try #require(weekly.addItem(named: "Milk"))
        milk.quantity = 2
        milk.product?.category = .dairyAndEggs
        weekly.addItem(named: "Coffee")?.setChecked(true)

        let joined = Household.create(in: context)
        let theirs = joined.addList()
        theirs.name = "Big Shop"
        theirs.addItem(named: "milk")

        mine.moveContents(to: joined)
        try context.save()

        #expect(mine.lists?.isEmpty ?? true)
        #expect(mine.products?.isEmpty ?? true)
        #expect(joined.products?.count == 2)

        let moved = try #require(joined.lists?.first { $0.name == "Weekly" })
        #expect(moved.colorName == "orange")
        #expect(moved.sortOrder > theirs.sortOrder)
        // Their existing "milk" absorbs ours rather than creating a second product.
        let theirMilk = try #require(theirs.items?.first?.product)
        let movedMilk = try #require(moved.items?.first { $0.product == theirMilk })
        #expect(movedMilk.quantity == 2)
        #expect(movedMilk.displayName == "milk")
        #expect(movedMilk.product?.category == .dairyAndEggs)
        #expect(moved.basket.map(\.displayName) == ["Coffee"])
    }

    @Test func showsTheChosenHouseholdThenFallsBackToOwn() {
        let mine = household
        let other = Household.create(in: context)
        let households = [mine, other]

        let otherID = other.uuid?.uuidString ?? ""
        #expect(HouseholdSelection.preferred(from: households, selectedID: otherID) == other)
        #expect(HouseholdSelection.preferred(from: households, selectedID: "gone") == mine)
        #expect(HouseholdSelection.preferred(from: [], selectedID: "") == nil)
    }

    // MARK: Prices

    @Test func parsesTypedPrices() {
        #expect(Money.minorUnits(from: "1.15") == 115)
        #expect(Money.minorUnits(from: " 2 ") == 200)
        #expect(Money.minorUnits(from: "0.999") == 100)
        #expect(Money.minorUnits(from: "1,15", locale: Locale(identifier: "de_DE")) == 115)
        #expect(Money.minorUnits(from: "-1") == nil)
        #expect(Money.minorUnits(from: "abc") == nil)
        #expect(Money.minorUnits(from: "") == nil)
    }

    @Test func seeingTheSamePriceTwiceInADayRecordsItOnce() {
        let store = household.addStore()
        let milk = household.product(named: "Milk")
        let morning = Date(timeIntervalSince1970: 1_800_000_000)

        let first = store.recordPrice(145, for: milk, on: morning)
        #expect(store.recordPrice(145, for: milk, on: morning.addingTimeInterval(3600)) == first)

        let changed = store.recordPrice(150, for: milk, on: morning.addingTimeInterval(7200))
        #expect(changed != first)
        #expect(milk.latestPrice(at: store) == changed)

        let nextDay = store.recordPrice(150, for: milk, on: morning.addingTimeInterval(86_400))
        #expect(nextDay != changed)
        #expect(store.prices?.count == 3)
        #expect(store.currentPrices == [nextDay])
    }

    @Test func pricesAreKeptPerStore() {
        let aldi = household.addStore()
        let coop = household.addStore()
        let milk = household.product(named: "Milk")
        aldi.recordPrice(145, for: milk)
        coop.recordPrice(175, for: milk)
        #expect(milk.latestPrice(at: aldi)?.amountMinor == 145)
        #expect(milk.latestPrice(at: coop)?.amountMinor == 175)
    }

    @Test func totalsCountQuantitiesAndOnlyPricedItems() throws {
        let store = household.addStore()
        let list = household.addList()
        let milk = try #require(list.addItem(named: "Milk"))
        milk.quantity = 2
        let bread = try #require(list.addItem(named: "Bread"))
        list.addItem(named: "Saffron")
        store.recordPrice(145, for: try #require(milk.product))
        store.recordPrice(129, for: try #require(bread.product))

        let total = StoreTotal(items: list.items ?? [], at: store)
        #expect(total.amountMinor == 145 * 2 + 129)
        #expect(total.pricedCount == 2)
        #expect(total.itemCount == 3)
    }

    @Test func mergingProductsKeepsTheirPrices() throws {
        let store = household.addStore()
        let older = household.product(named: "Milk")
        store.recordPrice(145, for: older, on: .now.addingTimeInterval(-86_400))
        try context.save()

        let newer = household.insertRelated(Product.self)
        newer.name = "milk"
        newer.normalizedName = "milk"
        newer.household = household
        newer.createdAt = .now.addingTimeInterval(60)
        let newerPrice = store.recordPrice(150, for: newer)

        household.mergeDuplicateProducts()
        try context.save()

        #expect(household.products == [older])
        #expect(older.prices?.count == 2)
        #expect(older.latestPrice(at: store) == newerPrice)
    }

    @Test func movingContentsCopiesStoresAndPrices() throws {
        let mine = household
        let store = mine.addStore()
        store.name = "Aldi"
        store.travel = .walk
        store.travelMinutes = 7
        store.recordPrice(145, for: mine.product(named: "Milk"))

        let joined = Household.create(in: context)
        mine.moveContents(to: joined)
        try context.save()

        #expect(mine.stores?.isEmpty ?? true)
        let moved = try #require(joined.stores?.first)
        #expect(moved.name == "Aldi")
        #expect(moved.travel == .walk)
        #expect(moved.travelMinutes == 7)
        let milk = try #require(joined.products?.first)
        #expect(milk.latestPrice(at: moved)?.amountMinor == 145)
    }

    @Test func storesRememberAndForgetTheirLocation() throws {
        let store = household.addStore()
        #expect(store.coordinate == nil)

        store.coordinate = CLLocationCoordinate2D(latitude: 51.4826, longitude: -0.0077)
        let coordinate = try #require(store.coordinate)
        #expect(coordinate.latitude == 51.4826)
        #expect(coordinate.longitude == -0.0077)

        let joined = Household.create(in: context)
        household.moveContents(to: joined)
        #expect(joined.stores?.first?.coordinate?.latitude == 51.4826)

        store.coordinate = nil
        #expect(!store.hasLocation)
    }

    @Test(arguments: ProductCategory.allCases)
    func categoryIconsExist(_ category: ProductCategory) {
        #expect(UIImage(systemName: category.symbolName) != nil, "\(category.symbolName) isn't an SF Symbol")
    }

    @Test(arguments: ListAppearance.symbolNames)
    func listIconsExist(_ symbolName: String) {
        #expect(UIImage(systemName: symbolName) != nil, "\(symbolName) isn't an SF Symbol")
    }
}
