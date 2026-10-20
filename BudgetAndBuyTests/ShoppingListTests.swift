import CoreData
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

    @Test(arguments: ProductCategory.allCases)
    func categoryIconsExist(_ category: ProductCategory) {
        #expect(UIImage(systemName: category.symbolName) != nil, "\(category.symbolName) isn't an SF Symbol")
    }

    @Test(arguments: ListAppearance.symbolNames)
    func listIconsExist(_ symbolName: String) {
        #expect(UIImage(systemName: symbolName) != nil, "\(symbolName) isn't an SF Symbol")
    }
}
