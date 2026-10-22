import CoreData

// Managed object classes for BudgetAndBuy.xcdatamodeld. Every attribute is optional
// or defaulted because CloudKit can deliver records with any field missing.

@objc(Household)
final class Household: NSManagedObject, Timestamped {
    @NSManaged var uuid: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var name: String?
    @NSManaged var colorName: String?
    /// Made automatically the first time the app runs on a device. Two devices
    /// can each make one before iCloud syncs; only these are ever merged.
    @NSManaged var isStarter: Bool
    /// Zero when no monthly budget is set.
    @NSManaged var monthlyBudgetMinor: Int64
    @NSManaged var lists: Set<ShoppingList>?
    @NSManaged var products: Set<Product>?
    @NSManaged var stores: Set<Store>?
    @NSManaged var trips: Set<Trip>?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        stamp()
    }
}

@objc(ShoppingList)
final class ShoppingList: NSManagedObject, Timestamped {
    @NSManaged var uuid: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var name: String?
    @NSManaged var colorName: String?
    @NSManaged var symbolName: String?
    @NSManaged var sortOrder: Double
    /// Zero when the list has no budget.
    @NSManaged var budgetMinor: Int64
    @NSManaged var household: Household?
    @NSManaged var items: Set<Item>?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        stamp()
    }
}

@objc(Item)
final class Item: NSManagedObject, Timestamped {
    @NSManaged var uuid: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var quantity: Int16
    @NSManaged var isChecked: Bool
    @NSManaged var checkedAt: Date?
    @NSManaged var list: ShoppingList?
    @NSManaged var product: Product?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        stamp()
    }
}

@objc(Product)
final class Product: NSManagedObject, Timestamped {
    @NSManaged var uuid: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var name: String?
    @NSManaged var normalizedName: String?
    /// Zero when the product has no size.
    @NSManaged var sizeAmount: Double
    @NSManaged var sizeUnit: String?
    @NSManaged var categoryID: String?
    /// A GroceryIcon raw value; empty once looked for and none fits.
    @NSManaged var iconID: String?
    @NSManaged var household: Household?
    @NSManaged var items: Set<Item>?
    @NSManaged var prices: Set<Price>?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        stamp()
    }
}

@objc(Store)
final class Store: NSManagedObject, Timestamped {
    @NSManaged var uuid: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var name: String?
    @NSManaged var colorName: String?
    /// The short address shown under the name, such as "200 Brighton Road, Coulsdon".
    @NSManaged var address: String?
    @NSManaged var fullAddress: String?
    /// Maps' identifier for the place, when the shop was found in Maps.
    @NSManaged var placeID: String?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var household: Household?
    @NSManaged var prices: Set<Price>?
    @NSManaged var trips: Set<Trip>?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        stamp()
    }
}

/// A price seen for a product at a store, or a note that it isn't sold
/// there. `createdAt` is when it was seen; the newest one is current.
@objc(Price)
final class Price: NSManagedObject, Timestamped {
    @NSManaged var uuid: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var amountMinor: Int64
    /// A sighting of the product not being sold there, rather than a price.
    @NSManaged var isUnavailable: Bool
    @NSManaged var product: Product?
    @NSManaged var store: Store?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        stamp()
    }
}

/// A finished shop. Names are copied rather than related so the record
/// survives the store or list being renamed or deleted.
@objc(Trip)
final class Trip: NSManagedObject, Timestamped {
    @NSManaged var uuid: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var storeName: String?
    @NSManaged var listName: String?
    @NSManaged var spentMinor: Int64
    @NSManaged var itemCount: Int16
    @NSManaged var pricedCount: Int16
    /// Items bought that had prices at other shops too, which the savings cover.
    @NSManaged var comparedCount: Int16
    /// What the compared items would have cost at your other shops, less what
    /// they cost here: positive when this trip was cheaper. Worked out from
    /// the prices known when the trip finished.
    @NSManaged var savedVsCheapestMinor: Int64
    @NSManaged var savedVsAverageMinor: Int64
    @NSManaged var savedVsDearestMinor: Int64
    @NSManaged var household: Household?
    @NSManaged var store: Store?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        stamp()
    }
}

/// Objects that can be ordered by age, so every device picks the same survivor
/// when merging duplicates created before they synced.
protocol Timestamped: NSManagedObject {
    var uuid: UUID? { get set }
    var createdAt: Date? { get set }
}

extension Timestamped {
    static var oldestFirst: [NSSortDescriptor] {
        [NSSortDescriptor(key: "createdAt", ascending: true), NSSortDescriptor(key: "uuid", ascending: true)]
    }

    static func isOlder(_ lhs: Self, than rhs: Self) -> Bool {
        let lhsDate = lhs.createdAt ?? .distantFuture
        let rhsDate = rhs.createdAt ?? .distantFuture
        if lhsDate != rhsDate { return lhsDate < rhsDate }
        return (lhs.uuid?.uuidString ?? "") < (rhs.uuid?.uuidString ?? "")
    }

    fileprivate func stamp() {
        uuid = UUID()
        createdAt = .now
    }
}

extension NSManagedObject {
    /// Inserts a new object into the same persistent store as this one.
    /// Core Data can't relate objects that live in different stores, and the
    /// private and shared iCloud databases are separate stores.
    func insertRelated<T: NSManagedObject>(_ type: T.Type) -> T {
        guard let context = managedObjectContext, let entityName = T.entity().name else {
            preconditionFailure("\(self) isn't in a managed object context")
        }
        let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! T
        if let store = objectID.persistentStore {
            context.assign(object, to: store)
        }
        return object
    }
}
