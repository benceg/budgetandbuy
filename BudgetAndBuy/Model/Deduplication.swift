import CoreData

extension NSManagedObjectContext {
    /// Every device creates a starter household on first launch, before iCloud
    /// has had a chance to deliver the one made elsewhere. Once they meet, keep
    /// the oldest starter and fold the others into it; each device reaches the
    /// same answer. Households people create themselves are never merged.
    ///
    /// A starter that's still empty once other households exist is dropped:
    /// it was made before your existing households arrived on this device.
    func mergeDuplicateHouseholds(in store: NSPersistentStore? = nil) throws {
        let request = NSFetchRequest<Household>(entityName: "Household")
        request.sortDescriptors = Household.oldestFirst
        if let store { request.affectedStores = [store] }

        let households = try fetch(request)
        let starters = households.filter(\.isStarter)
        if let keeper = starters.first {
            for duplicate in starters.dropFirst() {
                for list in duplicate.lists ?? [] { list.household = keeper }
                for product in duplicate.products ?? [] { product.household = keeper }
                for store in duplicate.stores ?? [] { store.household = keeper }
                for trip in duplicate.trips ?? [] { trip.household = keeper }
                processPendingChanges()
                delete(duplicate)
            }
            keeper.mergeDuplicateProducts()

            let others = households.filter { !$0.isStarter }
            if !others.isEmpty, keeper.isEmpty {
                delete(keeper)
            }
        }
        for household in households where !household.isStarter {
            household.mergeDuplicateProducts()
        }
    }
}

extension Household {
    /// Nothing in it yet: no lists, products, shops or trips.
    var isEmpty: Bool {
        (lists ?? []).isEmpty && (products ?? []).isEmpty && (stores ?? []).isEmpty && (trips ?? []).isEmpty
    }
}

extension Household {
    /// Two devices can each create "Milk 2 L" while offline. Keep the oldest
    /// product and point every item and price at it.
    func mergeDuplicateProducts() {
        let groups = Dictionary(grouping: products ?? []) { $0.identityKey }
        for group in groups.values where group.count > 1 {
            let sorted = group.sorted(by: Product.isOlder)
            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                if keeper.categoryID == nil { keeper.categoryID = duplicate.categoryID }
                if keeper.iconID == nil { keeper.iconID = duplicate.iconID }
                for item in duplicate.items ?? [] { item.product = keeper }
                for price in duplicate.prices ?? [] { price.product = keeper }
                // Deleting a product cascades to its prices; detach the moved ones first.
                managedObjectContext?.processPendingChanges()
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
