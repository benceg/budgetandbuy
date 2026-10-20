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

    @Test(arguments: ProductCategory.allCases)
    func categoryIconsExist(_ category: ProductCategory) {
        #expect(UIImage(systemName: category.symbolName) != nil, "\(category.symbolName) isn't an SF Symbol")
    }

    @Test(arguments: ListAppearance.symbolNames)
    func listIconsExist(_ symbolName: String) {
        #expect(UIImage(systemName: symbolName) != nil, "\(symbolName) isn't an SF Symbol")
    }
}
