import CoreData

extension Household {
    /// Moves every list, product, store and price into another household, such
    /// as one you've just joined. Households can live in different persistent
    /// stores, which can't be related, so this copies the objects across and
    /// deletes the originals.
    func moveContents(to destination: Household) {
        guard destination != self, let context = managedObjectContext else { return }

        var copies: [NSManagedObjectID: Product] = [:]
        for product in (products ?? []).sorted(by: Product.isOlder) {
            let copy = destination.product(named: product.name ?? "")
            if copy.categoryID == nil { copy.categoryID = product.categoryID }
            copies[product.objectID] = copy
        }

        for list in (lists ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let copy = destination.addList()
            copy.name = list.name
            copy.colorName = list.colorName
            copy.symbolName = list.symbolName
            for item in (list.items ?? []).sorted(by: Item.isOlder) {
                guard let product = item.product.flatMap({ copies[$0.objectID] }) else { continue }
                let itemCopy = copy.add(product)
                itemCopy.quantity = item.quantity
                itemCopy.isChecked = item.isChecked
                itemCopy.checkedAt = item.checkedAt
            }
            context.delete(list)
        }

        for store in (stores ?? []).sorted(by: Store.isOlder) {
            let copy = destination.addStore()
            copy.name = store.name
            copy.colorName = store.colorName
            copy.travelMode = store.travelMode
            copy.travelMinutes = store.travelMinutes
            copy.distanceKm = store.distanceKm
            for price in store.prices ?? [] {
                guard let product = price.product.flatMap({ copies[$0.objectID] }) else { continue }
                let priceCopy = copy.insertRelated(Price.self)
                priceCopy.amountMinor = price.amountMinor
                priceCopy.createdAt = price.createdAt
                priceCopy.product = product
                priceCopy.store = copy
            }
            context.delete(store)
        }

        for product in products ?? [] {
            context.delete(product)
        }
    }
}

enum HouseholdSelection {
    /// The household to show: the one last chosen if it still exists,
    /// otherwise one you've joined, otherwise your own.
    static func preferred(from households: [Household], selectedID: String) -> Household? {
        households.first { $0.uuid?.uuidString == selectedID }
            ?? households.first(where: \.isSharedWithMe)
            ?? households.first
    }
}
