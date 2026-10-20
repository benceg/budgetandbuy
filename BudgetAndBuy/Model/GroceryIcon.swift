import CoreData

/// A line icon for a kind of product, such as milk or nappies. The icons are
/// custom SF Symbols built from free icon sets by Tools/Icons/build.py.
struct GroceryIcon: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    /// Only names the catalogue uses, so a stored or generated name always has an image.
    init?(rawValue: String) {
        guard GroceryCatalogue.iconNames.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    fileprivate init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    var imageName: String { "grocery.\(rawValue)" }

    /// The icons for things sold in an aisle, in catalogue order.
    static func icons(in category: ProductCategory) -> [GroceryIcon] {
        var seen = Set<GroceryIcon>()
        return GroceryCatalogue.entries
            .filter { $0.category == category }
            .compactMap(\.icon)
            .filter { seen.insert($0).inserted }
    }
}

extension GroceryIcon: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(unchecked: value)
    }
}

extension Product {
    /// Setting nil records that no icon fits, so the product isn't looked at again.
    var icon: GroceryIcon? {
        get { iconID.flatMap(GroceryIcon.init(rawValue:)) }
        set { iconID = newValue?.rawValue ?? "" }
    }

    /// Fills in the aisle and icon of something the catalogue knows, leaving
    /// anything already chosen. Returns false if the catalogue doesn't know it.
    @discardableResult
    func fillInFromCatalogue() -> Bool {
        guard let entry = GroceryCatalogue.entry(for: name ?? "") else { return false }
        if categoryID == nil { category = entry.category }
        if iconID == nil { icon = entry.icon }
        return true
    }
}
