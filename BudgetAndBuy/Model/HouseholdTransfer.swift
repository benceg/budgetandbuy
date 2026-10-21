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
            copy.hasLocation = store.hasLocation
            copy.latitude = store.latitude
            copy.longitude = store.longitude
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
            copy.travelMode = trip.travelMode
            copy.spentMinor = trip.spentMinor
            copy.itemCount = trip.itemCount
            copy.pricedCount = trip.pricedCount
            copy.savedMinor = trip.savedMinor
            copy.comparedStoreName = trip.comparedStoreName
            copy.carbonKg = trip.carbonKg
            copy.carbonSavedKg = trip.carbonSavedKg
            copy.store = trip.store.flatMap { storeCopies[$0.objectID] }
            copy.household = destination
            context.delete(trip)
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
