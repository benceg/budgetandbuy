import CoreData

enum ProductName {
    /// The name as shown: trimmed, with runs of whitespace collapsed.
    static func display(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The key used to recognise the same product however it's typed:
    /// "Crème Fraîche" and "creme fraiche" match.
    static func normalized(_ name: String) -> String {
        display(name).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}

extension Household {
    static func create(in context: NSManagedObjectContext) -> Household {
        let household = Household(context: context)
        household.name = String(localized: "Home")
        return household
    }

    func addList() -> ShoppingList {
        let list = insertRelated(ShoppingList.self)
        list.sortOrder = ((lists ?? []).map(\.sortOrder).max() ?? -1) + 1
        list.household = self
        return list
    }

    /// The household's product with this name and size, created if it's new.
    func product(named rawName: String, size: ProductSize? = nil) -> Product {
        let name = ProductName.display(rawName)
        let key = ProductName.normalized(name)
        if let existing = (products ?? []).filter({ $0.matches(normalizedName: key, size: size) }).min(by: Product.isOlder) {
            return existing
        }
        let product = insertRelated(Product.self)
        product.name = name
        product.normalizedName = key
        product.size = size
        product.household = self
        return product
    }

    /// Products whose names contain `query`, best matches first.
    func products(matching query: String, limit: Int) -> [Product] {
        let key = ProductName.normalized(query)
        guard !key.isEmpty else { return [] }
        return (products ?? [])
            .filter { $0.normalizedName?.contains(key) == true }
            .sorted { lhs, rhs in
                let lhsPrefix = lhs.normalizedName?.hasPrefix(key) == true
                let rhsPrefix = rhs.normalizedName?.hasPrefix(key) == true
                if lhsPrefix != rhsPrefix { return lhsPrefix }
                return (lhs.normalizedName ?? "") < (rhs.normalizedName ?? "")
            }
            .prefix(limit)
            .map(\.self)
    }
}

extension ShoppingList {
    /// Adds a product to the list, reading a size off the name ("Milk 2L"),
    /// with its aisle and icon if the catalogue knows it. Adding something
    /// already on the list bumps its quantity; adding something already in
    /// the basket puts it back.
    @discardableResult
    func addItem(named rawName: String) -> Item? {
        let (name, size) = ProductSize.split(rawName)
        guard let household, !name.isEmpty else { return nil }
        let product = household.product(named: name, size: size)
        product.fillInFromCatalogue()
        return add(product)
    }

    @discardableResult
    func add(_ product: Product) -> Item {
        if let existing = (items ?? []).first(where: { $0.product == product }) {
            if existing.isChecked {
                existing.setChecked(false)
                existing.quantity = 1
            } else {
                existing.quantity += 1
            }
            return existing
        }
        let item = insertRelated(Item.self)
        item.product = product
        item.list = self
        return item
    }

    var basket: [Item] {
        (items ?? []).filter(\.isChecked)
    }
}

extension Item {
    var displayName: String { product?.title ?? "" }

    /// By name, ignoring case and accents; smaller sizes first for the same name.
    static func alphabetically(_ lhs: Item, _ rhs: Item) -> Bool {
        let order = (lhs.product?.name ?? "").localizedStandardCompare(rhs.product?.name ?? "")
        if order != .orderedSame { return order == .orderedAscending }
        return (lhs.product?.sizeAmount ?? 0) < (rhs.product?.sizeAmount ?? 0)
    }

    func setChecked(_ checked: Bool) {
        isChecked = checked
        checkedAt = checked ? .now : nil
    }
}
