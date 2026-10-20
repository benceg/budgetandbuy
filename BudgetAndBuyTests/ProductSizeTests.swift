import CoreData
import Testing
@testable import BudgetAndBuy

@MainActor
struct ProductSizeTests {
    let persistence = PersistenceController(inMemory: true)
    var household: Household { persistence.ensureHousehold() }

    @Test(arguments: [
        ("Milk 2L", "Milk", 2.0, ProductSize.Unit.litres),
        ("milk 2 l", "milk", 2.0, .litres),
        ("Semi-skimmed milk 4 pints", "Semi-skimmed milk", 4.0, .pints),
        ("4 pints semi-skimmed milk", "semi-skimmed milk", 4.0, .pints),
        ("Rice 1.5kg", "Rice", 1.5, .kilograms),
        ("Cheddar 400g", "Cheddar", 400.0, .grams),
        ("Cola 330ml", "Cola", 330.0, .millilitres),
        ("Eggs 6 pack", "Eggs", 6.0, .pack),
        ("Butter 0,5 kg", "Butter", 0.5, .kilograms),
    ])
    func readsSizesOffTypedNames(text: String, name: String, amount: Double, unit: ProductSize.Unit) {
        let (parsedName, size) = ProductSize.split(text)
        #expect(parsedName == name)
        #expect(size == ProductSize(amount: amount, unit: unit))
    }

    @Test(arguments: ["Milk", "7up", "Coke 330ml can", "Size 10 shoes", "2 Bananas"])
    func leavesNamesWithoutASizeAlone(text: String) {
        let (name, size) = ProductSize.split(text)
        #expect(name == text)
        #expect(size == nil)
    }

    @Test func differentSizesAreDifferentProducts() throws {
        let list = household.addList()
        let pint = try #require(list.addItem(named: "Milk 1 pint"))
        let litres = try #require(list.addItem(named: "Milk 2L"))
        let unsized = try #require(list.addItem(named: "milk"))
        let pintAgain = try #require(list.addItem(named: "milk 1pt"))

        #expect(Set([pint.product, litres.product, unsized.product]).count == 3)
        #expect(pintAgain == pint)
        #expect(pint.quantity == 2)
        #expect(litres.displayName == "Milk 2 L")
        #expect(unsized.displayName == "milk")
    }

    @Test func pricesUnitsTheWayShelfLabelsDo() throws {
        let litres = try #require(ProductSize(amount: 2, unit: .litres))
        #expect(litres.unitPrice(of: 145) == "\(Money.format(73))/L")
        let grams = try #require(ProductSize(amount: 400, unit: .grams))
        #expect(grams.unitPrice(of: 299) == "\(Money.format(748))/kg")
        let pints = try #require(ProductSize(amount: 4, unit: .pints))
        #expect(pints.unitPrice(of: 145) == "\(Money.format(64))/L")
    }

    @Test func mergesDuplicatesOnlyWhenTheSizeMatches() throws {
        let litres = household.product(named: "Milk", size: ProductSize(amount: 2, unit: .litres))
        let pint = household.product(named: "Milk", size: ProductSize(amount: 1, unit: .pints))
        let duplicate = household.insertRelated(Product.self)
        duplicate.name = "milk"
        duplicate.normalizedName = "milk"
        duplicate.size = ProductSize(amount: 2, unit: .litres)
        duplicate.household = household
        duplicate.createdAt = .now.addingTimeInterval(60)

        household.mergeDuplicateProducts()
        try persistence.viewContext.save()
        #expect(household.products == [litres, pint])
    }

    @Test func groupsItemsByAisleInAisleOrder() throws {
        let list = household.addList()
        let bread = try #require(list.addItem(named: "Bread"))
        bread.product?.category = .bakery
        let apples = try #require(list.addItem(named: "Apples"))
        apples.product?.category = .fruitAndVeg
        let mystery = try #require(list.addItem(named: "Mystery"))
        let pears = try #require(list.addItem(named: "Pears"))
        pears.product?.category = .fruitAndVeg

        let aisles = ProductCategory.aisles(of: [bread, apples, mystery, pears])
        #expect(aisles.map(\.category) == [.fruitAndVeg, .bakery, .other])
        #expect(aisles[0].items == [apples, pears])
        #expect(aisles[2].items == [mystery])
    }
}
