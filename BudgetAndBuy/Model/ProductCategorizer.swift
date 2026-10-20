import CoreData
import FoundationModels
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Categories")

/// Gives products an aisle and an icon. Things the catalogue knows get them
/// straight away; anything else is sorted by Apple's on-device language model,
/// so nothing leaves the device. Where the model isn't available (older
/// devices, or Apple Intelligence turned off), those products stay without
/// until someone picks an aisle and icon by hand.
@MainActor
final class ProductCategorizer {
    static let shared = ProductCategorizer()

    private var queue: [Product] = []
    private var worker: Task<Void, Never>?

    private nonisolated static let categoryInstructions = """
        You sort items from a UK household shopping list into the supermarket \
        department that sells them. Choose exactly one category:
        fruitAndVeg: fresh fruit, vegetables, salad, herbs.
        meatAndFish: fresh meat, poultry, fish, seafood.
        dairyAndEggs: milk, cheese, yoghurt, butter, eggs, chilled ready meals, fresh pasta, deli.
        bakery: bread, rolls, cakes, pastries, wraps.
        frozen: anything sold frozen.
        foodCupboard: tins, pasta, rice, cereal, sauces, spices, baking, spreads, tea, coffee.
        snacks: crisps, chocolate, sweets, biscuits, nuts.
        drinks: water, juice, soft drinks, beer, wine, spirits.
        baby: nappies, baby food, baby care.
        healthAndBeauty: toiletries, medicine, cosmetics, vitamins.
        household: cleaning, laundry, toilet roll, bin bags, foil, batteries.
        pets: pet food and pet care.
        homeAndGarden: kitchenware, homeware, plants, garden supplies.
        toysAndGames: toys, games, puzzles.
        electronics: chargers, cables, headphones, gadgets.
        clothing: clothes, socks, shoes.
        other: anything else.
        """

    private nonisolated static let iconInstructions = """
        You choose the icon for an item on a UK household shopping list. \
        Choose the icon that shows the item itself, or something it closely \
        resembles, such as a similar fruit or the same kind of packaging. \
        Choose none if no icon shows anything like it.
        """

    private nonisolated static let noIcon = "none"

    /// Fills in products that have no icon yet, from the catalogue or the model.
    func categorize(_ products: some Sequence<Product>) {
        let isModelAvailable = SystemLanguageModel.default.isAvailable
        for product in products where product.iconID == nil && !queue.contains(product) {
            if product.fillInFromCatalogue() {
                product.managedObjectContext?.saveIfNeeded()
            } else if isModelAvailable {
                queue.append(product)
            }
        }
        if worker == nil, !queue.isEmpty {
            worker = Task { await drain() }
        }
    }

    /// Queues every product in the context without an icon, such as on launch.
    func categorizeAll(in context: NSManagedObjectContext) {
        let request = NSFetchRequest<Product>(entityName: "Product")
        request.predicate = NSPredicate(format: "iconID == nil")
        categorize((try? context.fetch(request)) ?? [])
    }

    // One at a time: the model handles a single request well, and a backlog
    // shouldn't compete with someone typing.
    private func drain() async {
        while !queue.isEmpty {
            let product = queue.removeFirst()
            guard let name = product.name, !name.isEmpty else { continue }
            do {
                var category = product.category
                if category == nil {
                    let chosen = try await Self.category(for: name)
                    guard product.isUsable, product.categoryID == nil else { continue }
                    product.category = chosen
                    category = chosen
                }
                let choices = category.map(GroceryIcon.icons(in:)) ?? []
                let icon = choices.isEmpty ? nil : try await Self.icon(for: name, from: choices)
                // Someone may have chosen an icon by hand meanwhile.
                guard product.isUsable, product.iconID == nil else { continue }
                product.icon = icon
                product.managedObjectContext?.saveIfNeeded()
            } catch {
                logger.error("Categorising \(name, privacy: .private) failed: \(error)")
            }
        }
        worker = nil
    }

    private nonisolated static func category(for name: String) async throws -> ProductCategory {
        let session = LanguageModelSession(instructions: categoryInstructions)
        return try await session.respond(to: "Item: \(name)", generating: ProductCategory.self).content
    }

    /// Asks for one of the aisle's icons, so the answer is always a real icon.
    private nonisolated static func icon(for name: String, from choices: [GroceryIcon]) async throws -> GroceryIcon? {
        let schema = try GenerationSchema(
            root: DynamicGenerationSchema(
                name: "Icon",
                description: "The icon that best shows the item",
                anyOf: choices.map(\.rawValue) + [noIcon]
            ),
            dependencies: []
        )
        let session = LanguageModelSession(instructions: iconInstructions)
        let response = try await session.respond(to: "Item: \(name)", schema: schema)
        return GroceryIcon(rawValue: try response.content.value(String.self))
    }
}

private extension Product {
    var isUsable: Bool { !isDeleted && managedObjectContext != nil }
}
