#if DEBUG
import CoreData
import CoreLocation
import MapKit

/// Example shops, prices and a list around Coulsdon, for trying the app out.
/// Development builds only: none of this ships.
enum ExampleData {
    struct Shop {
        let name: String
        let colorName: String
        let travel: TravelMode
        let minutes: Int16
        let kilometres: Double
        /// Roughly where it is; refined from Maps when seeding.
        let coordinate: CLLocationCoordinate2D
        /// How its prices compare with the average.
        let priceLevel: Double
    }

    static let aldi = Shop(name: "Aldi Coulsdon", colorName: "slate", travel: .drive, minutes: 6, kilometres: 2.2,
                           coordinate: CLLocationCoordinate2D(latitude: 51.3265, longitude: -0.1368), priceLevel: 0.82)
    static let sainsburys = Shop(name: "Sainsbury’s Warlingham", colorName: "apricot", travel: .drive, minutes: 15, kilometres: 6.8,
                                 coordinate: CLLocationCoordinate2D(latitude: 51.3177, longitude: -0.0640), priceLevel: 1.0)
    static let tesco = Shop(name: "Tesco Express Coulsdon", colorName: "coral", travel: .walk, minutes: 5, kilometres: 0.4,
                            coordinate: CLLocationCoordinate2D(latitude: 51.3196, longitude: -0.1392), priceLevel: 1.14)
    static let waitrose = Shop(name: "Waitrose Coulsdon", colorName: "olive", travel: .walk, minutes: 8, kilometres: 0.6,
                               coordinate: CLLocationCoordinate2D(latitude: 51.3188, longitude: -0.1381), priceLevel: 1.27)

    static let shops = [aldi, sainsburys, tesco, waitrose]

    /// A product, its typical price in pence, and the shops that sell it:
    /// A Aldi, S Sainsbury's, T Tesco Express, W Waitrose. Most shops not
    /// listed are marked as not selling it; a few are left unknown.
    private static let products: [(name: String, pence: Double, soldAt: String)] = [
        ("Semi-skimmed milk 4 pints", 145, "ASTW"),
        ("Free-range eggs 6 pack", 199, "ASTW"),
        ("Cheddar 400g", 299, "ASTW"),
        ("Wholemeal bread 800g", 110, "ASTW"),
        ("Butter 250g", 219, "ASTW"),
        ("Bananas 5 pack", 89, "ASTW"),
        ("Apples 6 pack", 179, "AS W"),
        ("Carrots 1kg", 65, "AS W"),
        ("Potatoes 2.5kg", 149, "AS"),
        ("Onions 1kg", 85, "AS W"),
        ("Broccoli", 59, "AS W"),
        ("Tomatoes 6 pack", 95, "ASTW"),
        ("Chicken breasts 650g", 449, "AS W"),
        ("Beef mince 500g", 379, "AS W"),
        ("Salmon fillets 240g", 399, "AS W"),
        ("Penne 500g", 75, "ASTW"),
        ("Basmati rice 1kg", 179, "AS W"),
        ("Chopped tomatoes 400g", 55, "ASTW"),
        ("Baked beans 415g", 70, "ASTW"),
        ("Olive oil 500ml", 449, "AS W"),
        ("Cornflakes 500g", 199, "AST"),
        ("Porridge oats 1kg", 119, "AS W"),
        ("Tea bags 80 pack", 249, "ASTW"),
        ("Instant coffee 200g", 449, "ASTW"),
        ("Orange juice 1L", 129, "ASTW"),
        ("Greek yoghurt 500g", 149, "AS W"),
        ("Hummus 200g", 109, "S W"),
        ("Toilet roll 9 pack", 449, "AST"),
        ("Washing-up liquid 500ml", 119, "ASTW"),
        ("Laundry detergent 1.3L", 599, "AS"),
        ("Bin bags 20 pack", 199, "AST"),
        ("Cat food 12 pack", 449, "AS W"),
        ("Toothpaste 75ml", 149, "ASTW"),
        ("Shampoo 400ml", 249, "ASTW"),
        ("Paracetamol 16 pack", 45, "AST"),
        ("Crisps 6 pack", 149, "AST"),
        ("Milk chocolate 100g", 119, "ASTW"),
        // Only at Tesco Express.
        ("Ben & Jerry’s ice cream 465ml", 549, "T"),
        ("Monster energy drink 500ml", 165, "T"),
        ("Pot Noodle 90g", 120, "T"),
        // Only at Waitrose.
        ("Duchy Organic sourdough 800g", 279, "W"),
        ("Waitrose No.1 Cheddar 300g", 449, "W"),
        ("Sicilian lemon tart", 399, "W"),
    ]

    /// What's on the example list: a weekly shop that no one shop covers.
    private static let list = [
        "Semi-skimmed milk 4 pints", "Free-range eggs 6 pack", "Wholemeal bread 800g", "Bananas 5 pack", "Apples 6 pack",
        "Carrots 1kg", "Potatoes 2.5kg", "Chicken breasts 650g", "Penne 500g", "Chopped tomatoes 400g",
        "Greek yoghurt 500g", "Hummus 200g", "Tea bags 80 pack", "Toilet roll 9 pack", "Washing-up liquid 500ml",
        "Ben & Jerry’s ice cream 465ml", "Duchy Organic sourdough 800g",
    ]

    private static let letters: [Character: Shop] = ["A": aldi, "S": sainsburys, "T": tesco, "W": waitrose]

    /// Adds the shops, their prices and the example list to a household.
    /// Running it again tops things up rather than duplicating them.
    @MainActor
    static func load(into household: Household, placingOnMap: Bool = true) {
        guard let context = household.managedObjectContext else { return }
        var stores: [String: Store] = [:]
        let existing = household.stores ?? []
        for shop in shops {
            let store = existing.first { $0.name == shop.name } ?? household.addStore()
            store.name = shop.name
            store.colorName = shop.colorName
            store.travel = shop.travel
            store.travelMinutes = shop.minutes
            store.distanceKm = shop.kilometres
            if store.coordinate == nil { store.coordinate = shop.coordinate }
            stores[shop.name] = store
        }

        for (index, entry) in products.enumerated() {
            let (name, size) = ProductSize.split(entry.name)
            let product = household.product(named: name, size: size)
            product.fillInFromCatalogue()
            // Prices seen over the last fortnight.
            let seen = Calendar.current.date(byAdding: .day, value: -(index % 14), to: .now) ?? .now
            for (shopIndex, (letter, shop)) in letters.sorted(by: { $0.key < $1.key }).enumerated() {
                guard let store = stores[shop.name] else { continue }
                if entry.soldAt.contains(letter) {
                    store.recordPrice(price(entry.pence, at: shop, for: entry.name), for: product, on: seen)
                } else if (index + shopIndex) % 4 != 0 {
                    // Mostly noticed as not sold there; some just not looked for yet.
                    store.markUnavailable(product, on: seen)
                }
            }
        }

        let weekly = (household.lists ?? []).first { $0.name == "Example Weekly Shop" } ?? {
            let list = household.addList()
            list.name = "Example Weekly Shop"
            list.colorName = "sage"
            list.symbolName = "cart"
            list.budgetMinor = 6_000
            return list
        }()
        let onList = Set((weekly.items ?? []).compactMap(\.product))
        for name in list {
            let (productName, size) = ProductSize.split(name)
            let product = household.product(named: productName, size: size)
            if !onList.contains(product) { weekly.add(product) }
        }

        context.saveIfNeeded()
        ProductCategorizer.shared.categorize(household.products ?? [])
        guard placingOnMap else { return }
        Task {
            await placeOnMap(stores)
            await StoreArrivalMonitor.shared.refresh()
        }
    }

    /// Deletes everything in a household: lists, products and their prices,
    /// shops and trips. The household itself, its name and its members stay.
    @MainActor
    static func erase(_ household: Household) {
        guard let context = household.managedObjectContext else { return }
        let contents: [NSManagedObject] = Array(household.lists ?? []) + Array(household.products ?? [])
            + Array(household.stores ?? []) + Array(household.trips ?? [])
        for object in contents {
            context.delete(object)
        }
        household.monthlyBudgetMinor = 0
        context.saveIfNeeded()
        UserDefaults.standard.set("", forKey: "shoppingStoreID")
        Task { await StoreArrivalMonitor.shared.refresh() }
    }

    /// A shelf price: the typical price scaled by the shop's price level, with a
    /// little steady variation per product, ending in 5 or 9 like a real label.
    private static func price(_ pence: Double, at shop: Shop, for name: String) -> Int64 {
        let wobble = Double((name + shop.name).unicodeScalars.reduce(0) { $0 + Int($1.value) } % 11 - 5) / 100
        let raw = Int((pence * shop.priceLevel * (1 + wobble)).rounded())
        let rounded = max(10, (raw + 2) / 5 * 5)
        return Int64(rounded % 10 == 0 ? rounded - 1 : rounded)
    }

    /// Moves each shop to where Maps says it is, if Maps finds it close by.
    @MainActor
    private static func placeOnMap(_ stores: [String: Store]) async {
        for shop in shops {
            guard let store = stores[shop.name] else { continue }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = shop.name.replacingOccurrences(of: "’", with: "'")
            request.region = MKCoordinateRegion(center: shop.coordinate, latitudinalMeters: 8_000, longitudinalMeters: 8_000)
            let expected = CLLocation(latitude: shop.coordinate.latitude, longitude: shop.coordinate.longitude)
            guard let items = try? await MKLocalSearch(request: request).start().mapItems,
                  let match = items.min(by: { $0.location.distance(from: expected) < $1.location.distance(from: expected) }),
                  match.location.distance(from: expected) < 3_000 else { continue }
            // The shop may have been erased while Maps was searching.
            guard !store.isDeleted, let context = store.managedObjectContext,
                  (try? context.existingObject(with: store.objectID)) != nil else { continue }
            store.coordinate = match.location.coordinate
        }
        stores.values.first?.managedObjectContext?.saveIfNeeded()
    }
}
#endif
