import Foundation

/// Grocery aisles, loosely following Tesco's departments. Stored on Product by
/// raw value, so never rename a case once it has shipped.
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

    /// SF Symbols name, in its outline (line) form.
    var symbolName: String {
        switch self {
        case .fruitAndVeg: "carrot"
        case .meatAndFish: "fish"
        case .dairyAndEggs: "refrigerator"
        case .bakery: "birthday.cake"
        case .frozen: "snowflake"
        case .foodCupboard: "cabinet"
        case .snacks: "popcorn"
        case .drinks: "waterbottle"
        case .baby: "stroller"
        case .healthAndBeauty: "cross.case"
        case .household: "bubbles.and.sparkles"
        case .pets: "pawprint"
        case .homeAndGarden: "house"
        case .toysAndGames: "teddybear"
        case .electronics: "tv"
        case .clothing: "tshirt"
        case .other: "basket"
        }
    }
}

extension Product {
    var category: ProductCategory? {
        get { categoryID.flatMap(ProductCategory.init(rawValue:)) }
        set { categoryID = newValue?.rawValue }
    }
}
