import CoreData
import FoundationModels
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Categories")

/// Sorts products into aisles with Apple's on-device language model. Nothing
/// leaves the device. Where the model isn't available (older devices, or Apple
/// Intelligence turned off), products stay uncategorised until someone picks an
/// aisle by hand.
@MainActor
final class ProductCategorizer {
    static let shared = ProductCategorizer()

    private var queue: [Product] = []
    private var worker: Task<Void, Never>?

    private nonisolated static let instructions = """
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

    /// Queues products that have no category yet.
    func categorize(_ products: some Sequence<Product>) {
        guard SystemLanguageModel.default.isAvailable else { return }
        for product in products where product.categoryID == nil && !queue.contains(product) {
            queue.append(product)
        }
        if worker == nil, !queue.isEmpty {
            worker = Task { await drain() }
        }
    }

    /// Queues every uncategorised product in the context, such as on launch.
    func categorizeAll(in context: NSManagedObjectContext) {
        let request = NSFetchRequest<Product>(entityName: "Product")
        request.predicate = NSPredicate(format: "categoryID == nil")
        categorize((try? context.fetch(request)) ?? [])
    }

    // One at a time: the model handles a single request well, and a backlog
    // shouldn't compete with someone typing.
    private func drain() async {
        while !queue.isEmpty {
            let product = queue.removeFirst()
            guard let name = product.name, !name.isEmpty else { continue }
            do {
                let category = try await Self.category(for: name)
                guard !product.isDeleted, product.managedObjectContext != nil, product.categoryID == nil else { continue }
                product.category = category
                product.managedObjectContext?.saveIfNeeded()
            } catch {
                logger.error("Categorising \(name, privacy: .private) failed: \(error)")
            }
        }
        worker = nil
    }

    private nonisolated static func category(for name: String) async throws -> ProductCategory {
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: "Item: \(name)", generating: ProductCategory.self).content
    }
}
