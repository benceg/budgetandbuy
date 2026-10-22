import CoreData

extension Household {
    /// Moves every list, product, store, price and trip into another household,
    /// such as one you've just joined. Households can live in different
    /// persistent stores, which can't be related, so this copies the objects
    /// across and deletes the originals.
    func moveContents(to destination: Household) {
        guard destination != self, let context = managedObjectContext else { return }

        var copies: [NSManagedObjectID: Product] = [:]
        for product in (products ?? []).sorted(by: Product.isOlder) {
            let copy = destination.product(named: product.name ?? "", size: product.size)
            if copy.categoryID == nil { copy.categoryID = product.categoryID }
            if copy.iconID == nil { copy.iconID = product.iconID }
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

        var storeCopies: [NSManagedObjectID: Store] = [:]
        for store in (stores ?? []).sorted(by: Store.isOlder) {
            let copy = destination.addStore()
            storeCopies[store.objectID] = copy
            copy.name = store.name
            copy.colorName = store.colorName
            copy.travelMode = store.travelMode
            copy.travelMinutes = store.travelMinutes
            copy.distanceKm = store.distanceKm
            copy.place = store.place
            for price in store.prices ?? [] {
                guard let product = price.product.flatMap({ copies[$0.objectID] }) else { continue }
                let priceCopy = copy.insertRelated(Price.self)
                priceCopy.amountMinor = price.amountMinor
                priceCopy.isUnavailable = price.isUnavailable
                priceCopy.createdAt = price.createdAt
                priceCopy.product = product
                priceCopy.store = copy
            }
            context.delete(store)
        }

        for trip in trips ?? [] {
            let copy = destination.insertRelated(Trip.self)
            copy.createdAt = trip.createdAt
            copy.storeName = trip.storeName
            copy.listName = trip.listName
            copy.spentMinor = trip.spentMinor
            copy.itemCount = trip.itemCount
            copy.pricedCount = trip.pricedCount
            copy.savedMinor = trip.savedMinor
            copy.comparedStoreName = trip.comparedStoreName
            copy.store = trip.store.flatMap { storeCopies[$0.objectID] }
            copy.household = destination
            context.delete(trip)
        }

        for product in products ?? [] {
            context.delete(product)
        }
    }
}

extension Household {
    /// Copies another household's shops into this one, and optionally every
    /// price and "not sold here" seen at them, with the products they're for.
    /// Lists and trips stay where they are.
    func copyShops(from source: Household, includingPrices: Bool) {
        var products: [NSManagedObjectID: Product] = [:]
        for store in (source.stores ?? []).sorted(by: Store.isOlder) {
            let copy = addStore()
            copy.name = store.name
            copy.colorName = store.colorName
            copy.travelMode = store.travelMode
            copy.travelMinutes = store.travelMinutes
            copy.distanceKm = store.distanceKm
            copy.place = store.place
            guard includingPrices else { continue }
            for price in (store.prices ?? []).sorted(by: Price.isOlder) {
                guard let original = price.product else { continue }
                let product = products[original.objectID] ?? {
                    let product = self.product(named: original.name ?? "", size: original.size)
                    if product.categoryID == nil { product.categoryID = original.categoryID }
                    if product.iconID == nil { product.iconID = original.iconID }
                    products[original.objectID] = product
                    return product
                }()
                let priceCopy = copy.insertRelated(Price.self)
                priceCopy.amountMinor = price.amountMinor
                priceCopy.isUnavailable = price.isUnavailable
                priceCopy.createdAt = price.createdAt
                priceCopy.product = product
                priceCopy.store = copy
            }
        }
    }
}

enum HouseholdSelection {
    /// The current household: the one last used if it still exists,
    /// otherwise your own, otherwise one you've joined.
    static func preferred(from households: [Household], selectedID: String) -> Household? {
        households.first { $0.uuid?.uuidString == selectedID }
            ?? households.first(where: { !$0.isSharedWithMe })
            ?? households.first
    }

    /// Households in the order Home shows them: alphabetically.
    static func sorted(_ households: some Sequence<Household>) -> [Household] {
        households.sorted { lhs, rhs in
            let order = (lhs.name ?? "").localizedStandardCompare(rhs.name ?? "")
            return order == .orderedSame ? Household.isOlder(lhs, than: rhs) : order == .orderedAscending
        }
    }
}
