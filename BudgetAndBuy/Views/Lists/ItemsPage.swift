import CoreData
import SwiftUI

/// What's on the list, by aisle, with a field for adding more at the top.
struct ItemsPage: View {
    @ObservedObject var list: ShoppingList
    let toBuy: [Item]
    /// Most recently added to the basket first.
    let inBasket: [Item]
    let stores: [Store]
    let shoppingStore: Store?

    @Environment(\.managedObjectContext) private var context
    @AppStorage("groupsByAisle") private var groupsByAisle = true
    @State private var newItemName = ""
    @FocusState private var isAdding: Bool
    @State private var collapsedAisles: Set<ProductCategory> = []
    @State private var isBasketExpanded = true
    @State private var pricing: PricingTarget?

    /// Everyday things to start an empty list with.
    private static let starters = ["Milk", "Bread", "Eggs", "Bananas", "Apples", "Cheese", "Butter", "Pasta", "Tea", "Coffee", "Toilet roll", "Washing-up liquid"]

    private var items: [Item] { toBuy + inBasket }

    private var aisles: [(category: ProductCategory, items: [Item])] {
        guard groupsByAisle else { return [] }
        return ProductCategory.aisles(of: toBuy)
    }

    var body: some View {
        List {
            Section {
                addField
                ForEach(suggestions) { suggestion in
                    Button { add(suggestion) } label: {
                        SuggestionRow(suggestion: suggestion)
                    }
                }
            }
            .onSurface()

            if items.isEmpty && newItemName.isEmpty {
                Section {
                    starterItems
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if groupsByAisle {
                ForEach(aisles, id: \.category) { aisle in
                    let isCollapsed = collapsedAisles.contains(aisle.category)
                    Section {
                        if !isCollapsed {
                            ForEach(aisle.items, id: \.objectID, content: row)
                        }
                    } header: {
                        AisleHeader(category: aisle.category, count: aisle.items.count, isCollapsed: isCollapsed) {
                            withAnimation {
                                if isCollapsed { collapsedAisles.remove(aisle.category) } else { collapsedAisles.insert(aisle.category) }
                            }
                        }
                    }
                    .onSurface()
                }
            } else if !toBuy.isEmpty {
                Section {
                    ForEach(toBuy, id: \.objectID, content: row)
                } header: {
                    SectionHeading(title: "To Buy").textCase(nil)
                }
                .onSurface()
            }

            if !items.isEmpty && toBuy.isEmpty {
                Section {
                    Label("Everything’s in the basket", systemImage: "checkmark.circle")
                        .foregroundStyle(Color.forestInk)
                }
                .onSurface()
            }

            if !inBasket.isEmpty {
                Section(isExpanded: $isBasketExpanded) {
                    ForEach(inBasket, id: \.objectID, content: row)
                } header: {
                    AisleHeader(title: "In Basket", systemImage: "basket", count: inBasket.count, isCollapsed: !isBasketExpanded) {
                        withAnimation { isBasketExpanded.toggle() }
                    }
                }
                .onSurface()
            }
        }
        .themedList()
        .sheet(item: $pricing) { target in
            PriceSheet(target: target)
        }
    }

    // MARK: Adding

    private var addField: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.forestInk)
                .frame(width: 28)
                .accessibilityHidden(true)
            TextField("Add an item", text: $newItemName)
                .focused($isAdding)
                .submitLabel(.next)
                .onSubmit(addTyped)
            if !newItemName.isEmpty {
                Button("Add", action: addTyped)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.forestInk)
            }
        }
        .padding(.vertical, 6)
    }

    /// The household's own products first, then everyday things it hasn't bought yet.
    private var suggestions: [Suggestion] {
        guard let household = list.household else { return [] }
        let onList = Set(toBuy.compactMap(\.product))
        let typed = ProductSize.split(newItemName)
        let typedKey = ProductName.normalized(typed.name)
        let products = household.products(matching: typed.name, limit: 8)
        let known = Set(products.compactMap(\.normalizedName))
        let fromHousehold = products
            .filter { !onList.contains($0) && !$0.matches(normalizedName: typedKey, size: typed.size) }
            .map(Suggestion.product)
        let fromCatalogue = GroceryCatalogue.entries(matching: typed.name, limit: 8)
            .filter { entry in
                let key = ProductName.normalized(entry.name)
                return key != typedKey && !known.contains(key)
            }
            .map(Suggestion.catalogue)
        return Array((fromHousehold + fromCatalogue).prefix(4))
    }

    private var starterItems: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What do you need?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text("Type above, or tap to add a few everyday things.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
            FlowLayout(spacing: 8) {
                ForEach(Self.starters, id: \.self) { name in
                    Button {
                        list.addItem(named: name)
                        context.saveIfNeeded()
                    } label: {
                        HStack(spacing: 6) {
                            if let icon = GroceryCatalogue.entry(for: name)?.icon {
                                Image(icon.imageName)
                            }
                            Text(name)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.surface, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private func addTyped() {
        guard let item = list.addItem(named: newItemName) else {
            // Returning on an empty field ends entry, as in Reminders.
            isAdding = false
            return
        }
        context.saveIfNeeded()
        if let product = item.product {
            ProductCategorizer.shared.categorize([product])
        }
        newItemName = ""
        isAdding = true
    }

    private func add(_ suggestion: Suggestion) {
        switch suggestion {
        case .product(let product):
            list.add(product)
        case .catalogue(let entry):
            list.addItem(named: entry.name)
        }
        context.saveIfNeeded()
        newItemName = ""
    }

    // MARK: Rows

    private func row(_ item: Item) -> some View {
        ItemRow(
            item: item,
            store: shoppingStore,
            price: shoppingStore.flatMap { item.product?.latestPrice(at: $0) },
            onToggle: { toggle(item) },
            onPrice: { price(item) }
        )
    }

    /// Ticking an item off while shopping confirms its price here, or asks for
    /// one if this shop has none yet.
    private func toggle(_ item: Item) {
        withAnimation {
            item.setChecked(!item.isChecked)
        }
        if item.isChecked, let store = shoppingStore, let product = item.product {
            if let latest = product.latestPrice(at: store) {
                store.recordPrice(latest.amountMinor, for: product)
            } else {
                pricing = PricingTarget(product: product, store: store, isPrompt: true)
            }
        }
        context.saveIfNeeded()
    }

    private func price(_ item: Item) {
        guard let store = shoppingStore, let product = item.product else { return }
        pricing = PricingTarget(product: product, store: store)
    }
}

private struct AisleHeader: View {
    let title: LocalizedStringResource
    let systemImage: String
    let count: Int
    let isCollapsed: Bool
    let action: () -> Void

    init(category: ProductCategory, count: Int, isCollapsed: Bool, action: @escaping () -> Void) {
        title = category.title
        systemImage = category.symbolName
        self.count = count
        self.isCollapsed = isCollapsed
        self.action = action
    }

    init(title: LocalizedStringResource, systemImage: String, count: Int, isCollapsed: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.count = count
        self.isCollapsed = isCollapsed
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.forestInk)
                Text(title)
                    .foregroundStyle(Color.ink)
                Text(count, format: .number)
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .font(.headline)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityValue(isCollapsed ? Text("Collapsed") : Text("Expanded"))
    }
}

private struct ItemRow: View {
    @ObservedObject var item: Item
    let store: Store?
    let price: Price?
    let onToggle: () -> Void
    let onPrice: () -> Void

    var body: some View {
        NavigationLink(value: item) {
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(item.isChecked ? Color.forestInk : Color.sage)
                            .contentTransition(.symbolEffect(.replace))
                        ProductIcon(product: item.product)
                            .font(.title2)
                            .foregroundStyle(item.isChecked ? Color.inkSecondary : Color.ink)
                            .frame(width: 30)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.isChecked ? "Take \(item.displayName) out of the basket" : "Put \(item.displayName) in the basket")
                .sensoryFeedback(.selection, trigger: item.isChecked)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.product?.name ?? "")
                        .foregroundStyle(item.isChecked ? Color.inkSecondary : Color.ink)
                        .strikethrough(item.isChecked, color: Color.inkSecondary)
                    if let size = item.product?.size {
                        Text(size.formatted)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
        }
        .navigationLinkIndicatorVisibility(.hidden)
        .contextMenu {
            Button("Increase Quantity", systemImage: "plus") { changeQuantity(by: 1) }
            Button("Decrease Quantity", systemImage: "minus") { changeQuantity(by: -1) }
                .disabled(item.quantity <= 1)
            if store != nil {
                Button(price == nil ? "Add Price…" : "Change Price…", systemImage: "tag", action: onPrice)
            }
            Divider()
            Button("Remove from List", systemImage: "trash", role: .destructive, action: delete)
        }
        .swipeActions {
            Button("Remove", systemImage: "trash", role: .destructive, action: delete)
        }
        .swipeActions(edge: .leading) {
            Button(item.isChecked ? "Undo" : "In Basket", systemImage: item.isChecked ? "arrow.uturn.backward" : "basket", action: onToggle)
                .tint(.forest)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: 8) {
            if item.quantity > 1 {
                Tag(text: "×\(item.quantity)")
            }
            if store != nil {
                if let price {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Money.format(price.amountMinor * Int64(item.quantity)))
                            .foregroundStyle(Color.ink)
                        if let size = item.product?.size {
                            Text(size.unitPrice(of: price.amountMinor))
                                .font(.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                    .monospacedDigit()
                } else {
                    Button("Add Price", action: onPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.forestInk)
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private func changeQuantity(by delta: Int16) {
        item.quantity = max(1, item.quantity + delta)
        item.managedObjectContext?.saveIfNeeded()
    }

    private func delete() {
        let context = item.managedObjectContext
        withAnimation { context?.delete(item) }
        context?.saveIfNeeded()
    }
}

enum Suggestion: Identifiable {
    case product(Product)
    case catalogue(GroceryCatalogue.Entry)

    var id: String {
        switch self {
        case .product(let product): product.objectID.uriRepresentation().absoluteString
        case .catalogue(let entry): "catalogue:\(entry.name)"
        }
    }

    var title: String {
        switch self {
        case .product(let product): product.title
        case .catalogue(let entry): entry.name
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: Suggestion

    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch suggestion {
                case .product(let product):
                    ProductIcon(product: product)
                case .catalogue(let entry):
                    if let icon = entry.icon {
                        Image(icon.imageName)
                    } else {
                        Image(systemName: entry.category.symbolName)
                    }
                }
            }
            .font(.title3)
            .foregroundStyle(Color.inkSecondary)
            .frame(width: 28)
            Text(suggestion.title)
                .foregroundStyle(Color.ink)
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.forestInk)
        }
        .accessibilityLabel("Add \(suggestion.title)")
    }
}

/// Lays children out in rows, wrapping like words.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, in: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, in: bounds.width)
        for (index, origin) in rows.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, in width: CGFloat) -> (origins: [CGPoint], width: CGFloat, height: CGFloat) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (origins, maxX, y + rowHeight)
    }
}
