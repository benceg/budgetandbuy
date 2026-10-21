import CoreData
import Testing
import UIKit
@testable import BudgetAndBuy

@MainActor
struct GroceryCatalogueTests {
    let persistence = PersistenceController(inMemory: true)
    var household: Household { persistence.ensureHousehold() }

    @Test(arguments: GroceryCatalogue.iconNames.sorted())
    func iconsExist(_ name: String) throws {
        let icon = try #require(GroceryIcon(rawValue: name))
        #expect(UIImage(named: icon.imageName) != nil, "\(icon.imageName) isn't in the asset catalogue")
    }

    @Test(arguments: [
        ("Milk", "milk"),
        ("Semi-skimmed milk", "milk"),
        ("Chocolate milk", "milk"),
        ("Milk chocolate", "chocolate"),
        ("Peanut butter", "jar"),
        ("Coconut milk", "coconut-milk"),
        ("Tea towels", "towel"),
        ("banana", "banana"),
        ("Tomatoes", "tomato"),
        ("Cherry tomatoes", "tomato"),
        ("Chicken breasts", "drumstick"),
        ("Free-range chicken thighs", "drumstick"),
        ("Dishwasher tablets", "detergent"),
        ("Cheese and onion crisps", nil),
        ("New potatoes", "potato"),
        ("Orange squash", "juice"),
    ] as [(String, String?)])
    func recognisesItemsInLongerNames(_ name: String, _ icon: String?) throws {
        let entry = try #require(GroceryCatalogue.entry(for: name))
        #expect(entry.icon?.rawValue == icon)
    }

    @Test func doesNotGuessAtUnknownItems() {
        #expect(GroceryCatalogue.entry(for: "Celeriac") == nil)
        #expect(GroceryCatalogue.entry(for: "") == nil)
    }

    @Test func suggestsPrefixMatchesFirst() {
        let names = GroceryCatalogue.entries(matching: "mil", limit: 3).map(\.name)
        #expect(names.first == "Milk")
        #expect(GroceryCatalogue.entries(matching: "  ", limit: 3).isEmpty)
    }

    @Test func eachAisleOffersItsIconsOnce() {
        let icons = GroceryIcon.icons(in: .dairyAndEggs)
        #expect(icons.first?.rawValue == "milk")
        #expect(Set(icons).count == icons.count)
        #expect(GroceryIcon.icons(in: .other).isEmpty)
    }

    @Test func addingAKnownItemFillsInItsAisleAndIcon() throws {
        let list = household.addList()
        let milk = try #require(list.addItem(named: "Semi-skimmed milk 2L")?.product)
        #expect(milk.category == .dairyAndEggs)
        #expect(milk.icon?.rawValue == "milk")

        // Known, but without an icon: it isn't looked at again.
        let butter = try #require(list.addItem(named: "Butter")?.product)
        #expect(butter.category == .dairyAndEggs)
        #expect(butter.iconID == "")

        let unknown = try #require(list.addItem(named: "Celeriac")?.product)
        #expect(unknown.category == nil)
        #expect(unknown.iconID == nil)
    }

    @Test func keepsAnAisleAndIconChosenByHand() throws {
        let list = household.addList()
        let product = try #require(list.addItem(named: "Bread")?.product)
        product.category = .frozen
        product.icon = GroceryIcon(rawValue: "frozen")
        list.addItem(named: "bread")
        #expect(product.category == .frozen)
        #expect(product.icon?.rawValue == "frozen")
    }

    @Test func storedIconsMustBeKnown() {
        let product = household.product(named: "Thing")
        product.iconID = "not-an-icon"
        #expect(product.icon == nil)
    }

    @Test func movingAndMergingKeepIcons() throws {
        let mine = household
        let product = mine.product(named: "Celeriac")
        product.icon = GroceryIcon(rawValue: "carrot")

        let joined = Household.create(in: persistence.viewContext)
        mine.moveContents(to: joined)
        #expect(joined.products?.first?.icon?.rawValue == "carrot")

        // The same product added on two devices: the older one is kept.
        let older = joined.product(named: "Swede")
        older.createdAt = .distantPast
        let newer = joined.insertRelated(Product.self)
        newer.name = "Swede"
        newer.normalizedName = "swede"
        newer.household = joined
        newer.icon = GroceryIcon(rawValue: "radish")
        joined.mergeDuplicateProducts()
        #expect(older.icon?.rawValue == "radish")
    }
}
