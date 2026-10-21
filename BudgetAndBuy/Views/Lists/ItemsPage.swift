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
    @AppStorage(ItemLayout.storageKey) private var layout: ItemLayout = .list
    /// The item whose details a long-pressed tile opens.
    @State private var detailItem: Item?
    @State private var newItemName = ""
    @FocusState private var isAdding: Bool
    @State private var collapsedAisles: Set<ProductCategory> = []
    @State private var isBasketExpanded = true
    @State private var pricing: PricingTarget?
    /// Items just ticked, shown ticked where they are before moving to the basket.
    @State private var ticking: Set<NSManagedObjectID> = []
    /// Items shrinking away before they move between the list and the basket.
    @State private var leaving: Set<NSManagedObjectID> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long a ticked item stays in place before moving to the basket.
    private static let tickPause: Duration = .milliseconds(450)
    /// How long a row takes to shrink away before it moves.
    private static let leaveDuration = 0.22

    /// Everyday things to start an empty list with.
    private static let starters = ["Milk", "Bread", "Eggs", "Bananas", "Apples", "Cheese", "Butter", "Pasta", "Tea", "Coffee", "Toilet roll", "Washing-up liquid"]

    private var items: [Item] { toBuy + inBasket }

    private var aisles: [(category: ProductCategory, items: [Item])] {
        guard groupsByAisle else { return [] }
        return ProductCategory.aisles(of: toBuy)
    }

    var body: some View {
        Group {
            switch layout {
            case .list: listView
            case .tiles: tilesView
            }
        }
        .scrollDismissesKeyboard(.immediately)
        #if DEBUG
        .task {
            if let typed = DebugLaunch.typedItem {
                newItemName = typed
                isAdding = true
            }
            guard DebugLaunch.ticksFirstItem else { return }
            try? await Task.sleep(for: .seconds(1))
            if let first = toBuy.first { toggle(first) }
        }
        #endif
        .sheet(item: $pricing) { target in
            PriceSheet(target: target)
        }
        .navigationDestination(item: $detailItem) { item in
            ItemDetailView(item: item)
        }
    }

    private var suggestionRows: some View {
        ForEach(suggestions) { suggestion in
            if case .added = suggestion {
                SuggestionRow(suggestion: suggestion)
            } else {
                Button { add(suggestion) } label: {
                    SuggestionRow(suggestion: suggestion)
                }
            }
        }
    }

    // MARK: List

    private var listView: some View {
        List {
            Section {
                addField
                suggestionRows
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
                        .closesKeyboard(when: isAdding) { isAdding = false }
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
                        .foregroundStyle(Color.brandInk)
                }
                .onSurface()
            }

            if !inBasket.isEmpty {
                Section(isExpanded: $isBasketExpanded) {
                    ForEach(inBasket, id: \.objectID, content: row)
                } header: {
                    AisleHeader(title: "In Basket", icon: Image(systemName: "basket"), count: inBasket.count, isCollapsed: !isBasketExpanded) {
                        withAnimation { isBasketExpanded.toggle() }
                    }
                    .closesKeyboard(when: isAdding) { isAdding = false }
                }
                .onSurface()
            }
        }
        .themedList()
        .contentMargins(.top, 4, for: .scrollContent)
    }

    // MARK: Tiles

    /// The smallest a tile can be; larger text makes tiles bigger, so fewer fit.
    @ScaledMetric(relativeTo: .body) private var minimumTileWidth: CGFloat = 88
    private let tileSpacing: CGFloat = 10

    private var tilesView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 32
            let fitting = Int((width + tileSpacing) / (minimumTileWidth + tileSpacing))
            let columns = Array(repeating: GridItem(.flexible(), spacing: tileSpacing), count: min(4, max(2, fitting)))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 0) {
                        addField
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        ForEach(suggestions) { suggestion in
                            Divider().overlay(Color.hairline).padding(.leading, 56)
                            Group {
                                if case .added = suggestion {
                                    SuggestionRow(suggestion: suggestion)
                                } else {
                                    Button { add(suggestion) } label: {
                                        SuggestionRow(suggestion: suggestion).contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                        }
                    }
                    .background(Color.surface, in: .rect(cornerRadius: 22, style: .continuous))

                    if items.isEmpty && newItemName.isEmpty {
                        starterItems
                    }

                    if groupsByAisle {
                        ForEach(aisles, id: \.category) { aisle in
                            let isCollapsed = collapsedAisles.contains(aisle.category)
                            tileSection(items: isCollapsed ? [] : aisle.items, columns: columns) {
                                AisleHeader(category: aisle.category, count: aisle.items.count, isCollapsed: isCollapsed) {
                                    withAnimation {
                                        if isCollapsed { collapsedAisles.remove(aisle.category) } else { collapsedAisles.insert(aisle.category) }
                                    }
                                }
                            }
                        }
                    } else if !toBuy.isEmpty {
                        tileSection(items: toBuy, columns: columns) {
                            SectionHeading(title: "To Buy")
                        }
                    }

                    if !items.isEmpty && toBuy.isEmpty {
                        Label("Everything’s in the basket", systemImage: "checkmark.circle")
                            .foregroundStyle(Color.brandInk)
                            .card()
                    }

                    if !inBasket.isEmpty {
                        tileSection(items: isBasketExpanded ? inBasket : [], columns: columns) {
                            AisleHeader(title: "In Basket", icon: Image(systemName: "basket"), count: inBasket.count, isCollapsed: !isBasketExpanded) {
                                withAnimation { isBasketExpanded.toggle() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .canvasBackground()
        }
    }

    private func tileSection<Header: View>(items: [Item], columns: [GridItem], @ViewBuilder header: () -> Header) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header()
                .padding(.horizontal, 4)
                .closesKeyboard(when: isAdding) { isAdding = false }
            LazyVGrid(columns: columns, spacing: tileSpacing) {
                ForEach(items, id: \.objectID) { item in
                    ItemTile(
                        item: item,
                        isTicking: ticking.contains(item.objectID),
                        isLeaving: leaving.contains(item.objectID),
                        reduceMotion: reduceMotion,
                        onToggle: { toggle(item) },
                        onOpen: { detailItem = item }
                    )
                    .closesKeyboard(when: isAdding) { isAdding = false }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Adding

    private var addField: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brandInk)
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
                    .foregroundStyle(Color.brandInk)
            }
        }
        .padding(.vertical, 6)
    }

    /// The household's own products first, then everyday things it hasn't
    /// bought yet. Things already on the list show too, marked as added.
    private var suggestions: [Suggestion] {
        guard let household = list.household else { return [] }
        let onList = Set(toBuy.compactMap(\.product))
        let typed = ProductSize.split(newItemName)
        let typedKey = ProductName.normalized(typed.name)
        let products = household.products(matching: typed.name, limit: 8)
        let known = Set(products.compactMap(\.normalizedName))
        let fromHousehold = products
            .filter { onList.contains($0) || !$0.matches(normalizedName: typedKey, size: typed.size) }
            .map { onList.contains($0) ? Suggestion.added($0) : .product($0) }
        let fromCatalogue = GroceryCatalogue.entries(matching: typed.name, limit: 8)
            .filter { entry in
                let key = ProductName.normalized(entry.name)
                return key != typedKey && !known.contains(key)
            }
            .map(Suggestion.catalogue)
        return Array((fromHousehold + fromCatalogue).prefix(5))
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
        case .added:
            return
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
            isTicking: ticking.contains(item.objectID),
            isLeaving: leaving.contains(item.objectID),
            reduceMotion: reduceMotion,
            onToggle: { toggle(item) },
            onPrice: { price(item) }
        )
        .closesKeyboard(when: isAdding) { isAdding = false }
    }

    /// Ticking shows the tick where the item is, then moves it to the basket a
    /// moment later; tapping again in that moment keeps it on the list.
    /// Unticking moves it straight back.
    private func toggle(_ item: Item) {
        let id = item.objectID
        guard !leaving.contains(id) else { return }
        if item.isChecked {
            Task { await move(item, toBasket: false) }
        } else if ticking.contains(id) {
            ticking.remove(id)
        } else {
            ticking.insert(id)
            Task {
                try? await Task.sleep(for: Self.tickPause)
                guard ticking.contains(id), !item.isDeleted, !item.isChecked else { return }
                await move(item, toBasket: true)
                ticking.remove(id)
            }
        }
    }

    /// Shrinks the row away, then moves the item, letting the list close the
    /// gap and fade it in at the other end.
    private func move(_ item: Item, toBasket: Bool) async {
        let id = item.objectID
        withAnimation(.easeIn(duration: Self.leaveDuration)) { _ = leaving.insert(id) }
        try? await Task.sleep(for: .seconds(Self.leaveDuration))
        guard !item.isDeleted else {
            leaving.remove(id)
            return
        }
        // Processing the change inside the animation updates the list's
        // fetches straight away, so the move animates rather than jumping.
        withAnimation(.snappy(duration: 0.35)) {
            item.setChecked(toBasket)
            context.processPendingChanges()
            leaving.remove(id)
        }
        if toBasket {
            putInBasket(item)
        } else {
            context.saveIfNeeded()
        }
    }

    /// Putting an item in the basket while shopping confirms its price here,
    /// or asks for one if this shop has none yet.
    private func putInBasket(_ item: Item) {
        if let store = shoppingStore, let product = item.product {
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
    let icon: Image
    let count: Int
    let isCollapsed: Bool
    let action: () -> Void

    init(category: ProductCategory, count: Int, isCollapsed: Bool, action: @escaping () -> Void) {
        title = category.title
        icon = Image(category.icon.imageName)
        self.count = count
        self.isCollapsed = isCollapsed
        self.action = action
    }

    init(title: LocalizedStringResource, icon: Image, count: Int, isCollapsed: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.count = count
        self.isCollapsed = isCollapsed
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon
                    .foregroundStyle(Color.brandInk)
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
    /// Just ticked and about to move to the basket.
    let isTicking: Bool
    /// Shrinking away before moving between the list and the basket.
    let isLeaving: Bool
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onPrice: () -> Void

    /// Counts taps on the tick, so the haptic follows taps rather than every
    /// change in how the row looks.
    @State private var tapCount = 0

    private var looksChecked: Bool { item.isChecked || isTicking }

    var body: some View {
        NavigationLink(value: item) {
            HStack(spacing: 12) {
                Button {
                    tapCount += 1
                    onToggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: looksChecked ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(looksChecked ? Color.brandInk : Color.brandSoft)
                            .contentTransition(.symbolEffect(.replace))
                        ProductIcon(product: item.product)
                            .font(.title2)
                            .foregroundStyle(looksChecked ? Color.inkSecondary : Color.ink)
                            .frame(width: 30)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(looksChecked ? "Take \(item.displayName) out of the basket" : "Put \(item.displayName) in the basket")
                .sensoryFeedback(.selection, trigger: tapCount)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.product?.name ?? "")
                        .foregroundStyle(looksChecked ? Color.inkSecondary : Color.ink)
                        .strikethrough(looksChecked, color: Color.inkSecondary)
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
        .scaleEffect(isLeaving && !reduceMotion ? 0.85 : 1)
        .opacity(isLeaving ? 0 : 1)
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
                .tint(.brand)
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
                        .foregroundStyle(Color.brandInk)
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

/// An item as a rounded square: a larger icon, with its name and how many
/// beneath. Tap to put it in the basket (or take it out); long press for details.
private struct ItemTile: View {
    @ObservedObject var item: Item
    let isTicking: Bool
    let isLeaving: Bool
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    @State private var isPressing = false
    /// Counts long presses, so the haptic plays when details open and not
    /// when a finger merely lands on a tile, as it does at the start of a scroll.
    @State private var openCount = 0
    @State private var tapCount = 0

    private var looksChecked: Bool { item.isChecked || isTicking }

    private var detail: String? {
        let parts = [item.product?.size?.formatted, item.quantity > 1 ? "×\(item.quantity)" : nil].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        // A clear square sized by the column width keeps every tile square,
        // however long its name.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { content }
            .background(looksChecked ? Color.brandPale : Color.surface, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if looksChecked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.onBrand, Color.brand)
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
            .scaleEffect(isLeaving && !reduceMotion ? 0.7 : isPressing ? 0.95 : 1)
            .opacity(isLeaving ? 0 : 1)
            .animation(.snappy(duration: 0.2), value: isPressing)
            .animation(.snappy(duration: 0.2), value: looksChecked)
            .onTapGesture {
                tapCount += 1
                onToggle()
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                openCount += 1
                onOpen()
            } onPressingChanged: { pressing in
                isPressing = pressing
            }
            .sensoryFeedback(.selection, trigger: tapCount)
            .sensoryFeedback(.impact(weight: .medium), trigger: openCount)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([item.product?.name, detail].compactMap(\.self).joined(separator: ", "))
            .accessibilityValue(looksChecked ? Text("In basket") : Text("To buy"))
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(looksChecked ? Text("Takes it out of the basket") : Text("Puts it in the basket"))
            .accessibilityAction(named: Text("Show Details"), onOpen)
    }

    private var content: some View {
        VStack(spacing: 3) {
            ProductIcon(product: item.product)
                .font(.system(size: 25))
                .foregroundStyle(looksChecked ? Color.inkSecondary : Color.ink)
                .frame(height: 28)
            Text(item.product?.name ?? "")
                .font(.caption.weight(.medium))
                .foregroundStyle(looksChecked ? Color.inkSecondary : Color.ink)
                .strikethrough(looksChecked, color: Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(6)
    }
}

enum Suggestion: Identifiable {
    case product(Product)
    case catalogue(GroceryCatalogue.Entry)
    /// Already on the list: shown, but not added again.
    case added(Product)

    var id: String {
        switch self {
        case .product(let product), .added(let product): product.objectID.uriRepresentation().absoluteString
        case .catalogue(let entry): "catalogue:\(entry.name)"
        }
    }

    var title: String {
        switch self {
        case .product(let product), .added(let product): product.title
        case .catalogue(let entry): entry.name
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: Suggestion

    private var isAdded: Bool {
        if case .added = suggestion { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch suggestion {
                case .product(let product), .added(let product):
                    ProductIcon(product: product)
                case .catalogue(let entry):
                    if let icon = entry.icon {
                        Image(icon.imageName)
                    } else {
                        Image(entry.category.icon.imageName)
                    }
                }
            }
            .font(.title3)
            .foregroundStyle(Color.inkSecondary)
            .frame(width: 28)
            Text(suggestion.title)
                .foregroundStyle(isAdded ? Color.inkSecondary : Color.ink)
            Spacer()
            if isAdded {
                Text("Added")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(Color.inkSecondary)
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandInk)
            }
        }
        .opacity(isAdded ? 0.7 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isAdded ? "\(suggestion.title), already on the list" : "Add \(suggestion.title)")
    }
}

private extension View {
    /// While typing, a tap here closes the keyboard instead of doing what it
    /// normally would.
    func closesKeyboard(when isTyping: Bool, close: @escaping () -> Void) -> some View {
        overlay {
            if isTyping {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture(perform: close)
            }
        }
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


/// How a list's items are shown: rows, or a grid of tiles.
enum ItemLayout: String, CaseIterable, Identifiable {
    case list, tiles

    static let storageKey = "itemLayout"

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .list: "List"
        case .tiles: "Tiles"
        }
    }
}
