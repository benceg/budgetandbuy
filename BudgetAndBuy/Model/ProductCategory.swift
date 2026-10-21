import Foundation
import FoundationModels

/// Grocery aisles, loosely following Tesco's departments. Stored on Product by
/// raw value, so never rename a case once it has shipped.
@Generable
enum ProductCategory: String, CaseIterable, Identifiable {
    case fruitAndVeg
    case meatAndFish
    case dairyAndEggs
    case bakery
    case frozen
    case foodCupboard
    case snacks
    case drinks
    case baby
    case healthAndBeauty
    case household
    case pets
    case homeAndGarden
    case toysAndGames
    case electronics
    case clothing
    case other

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .fruitAndVeg: "Fruit & Veg"
        case .meatAndFish: "Meat & Fish"
        case .dairyAndEggs: "Dairy, Eggs & Chilled"
        case .bakery: "Bakery"
        case .frozen: "Frozen"
        case .foodCupboard: "Food Cupboard"
        case .snacks: "Treats & Snacks"
        case .drinks: "Drinks"
        case .baby: "Baby & Toddler"
        case .healthAndBeauty: "Health & Beauty"
        case .household: "Household"
        case .pets: "Pets"
        case .homeAndGarden: "Home & Garden"
        case .toysAndGames: "Toys & Games"
        case .electronics: "Electronics"
        case .clothing: "Clothing"
        case .other: "Other"
        }
    }

    /// The aisle's icon, from the same set as product icons. Products with no
    /// icon of their own show it, so it's kept general: leaves, not a carrot.
    var icon: GroceryIcon {
        switch self {
        case .fruitAndVeg: "produce"
        case .meatAndFish: "meat"
        case .dairyAndEggs: "milk-carton"
        case .bakery: "bread"
        case .frozen: "frozen"
        case .foodCupboard: "tin"
        case .snacks: "sweets"
        case .drinks: "water"
        case .baby: "baby-bottle"
        case .healthAndBeauty: "tablets"
        case .household: "spray"
        case .pets: "paw"
        case .homeAndGarden: "plant"
        case .toysAndGames: "bricks"
        case .electronics: "charger"
        case .clothing: "tshirt"
        case .other: "bag"
        }
    }
}

extension Product {
    var category: ProductCategory? {
        get { categoryID.flatMap(ProductCategory.init(rawValue:)) }
        set { categoryID = newValue?.rawValue }
    }
}

extension ProductCategory {
    /// Groups items by aisle, in aisle order, alphabetically within each.
    /// Uncategorised items join Other.
    static func aisles(of items: [Item]) -> [(category: ProductCategory, items: [Item])] {
        let grouped = Dictionary(grouping: items.sorted(by: Item.alphabetically)) { $0.product?.category ?? .other }
        return allCases.compactMap { category in
            grouped[category].map { (category, $0) }
        }
    }
}
