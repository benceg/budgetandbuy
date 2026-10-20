import CoreData

extension NSManagedObjectContext {
    /// Every device creates a household on first launch, before iCloud has had a
    /// chance to deliver the one made elsewhere. Once they meet, keep the oldest
    /// and fold the others into it. Each device reaches the same answer.
    func mergeDuplicateHouseholds(in store: NSPersistentStore? = nil) throws {
        let request = NSFetchRequest<Household>(entityName: "Household")
        request.sortDescriptors = Household.oldestFirst
        if let store { request.affectedStores = [store] }

        let households = try fetch(request)
        guard let keeper = households.first else { return }

        for duplicate in households.dropFirst() {
            for list in duplicate.lists ?? [] { list.household = keeper }
            for product in duplicate.products ?? [] { product.household = keeper }
            processPendingChanges()
            delete(duplicate)
        }
        keeper.mergeDuplicateProducts()
    }
}

extension Household {
    /// Two devices can each create "Milk" while offline. Keep the oldest product
    /// and point every item at it.
    func mergeDuplicateProducts() {
        let groups = Dictionary(grouping: products ?? []) { $0.normalizedName ?? "" }
        for group in groups.values where group.count > 1 {
            let sorted = group.sorted(by: Product.isOlder)
            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                if keeper.categoryID == nil { keeper.categoryID = duplicate.categoryID }
                for item in duplicate.items ?? [] { item.product = keeper }
                managedObjectContext?.delete(duplicate)
            }
        }
        for list in lists ?? [] { list.mergeDuplicateItems() }
    }
}

extension ShoppingList {
    /// After products merge, a list can hold the same product twice. Keep one row,
    /// still to buy if either was, with the larger quantity.
    func mergeDuplicateItems() {
        let groups = Dictionary(grouping: (items ?? []).filter { $0.product != nil }) { $0.product!.objectID }
        for group in groups.values where group.count > 1 {
            let sorted = group.sorted(by: Item.isOlder)
            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                keeper.quantity = max(keeper.quantity, duplicate.quantity)
                if !duplicate.isChecked { keeper.setChecked(false) }
                managedObjectContext?.delete(duplicate)
            }
        }
    }
}
