import CoreData
import SwiftUI

struct ListDetailView: View {
    @ObservedObject var list: ShoppingList
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var items: FetchedResults<Item>
    @FetchRequest private var stores: FetchedResults<Store>
    // Fetched so totals and row prices refresh whenever any price changes.
    @FetchRequest private var prices: FetchedResults<Price>
    /// The store you're shopping in, per device and shared by all lists.
    @AppStorage("shoppingStoreID") private var shoppingStoreID = ""
    @State private var newItemName = ""
    @FocusState private var isAddingItem: Bool
    @State private var isBasketExpanded = true
    @State private var isEditingInfo = false
    @State private var isConfirmingClear = false
    @State private var isConfirmingDeletion = false
    @State private var isAddingStore = false
    @State private var isComparing = false
    @State private var finishedTrip: FinishedTrip?
    @State private var pricing: PricingTarget?

    init(list: ShoppingList) {
        self.list = list
        _items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)],
            predicate: NSPredicate(format: "list == %@", list),
            animation: .default
        )
        // A list being deleted has no household; match nothing rather than everything.
        let household = list.household
        _stores = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))],
            predicate: household.map { NSPredicate(format: "household == %@", $0) } ?? NSPredicate(value: false)
        )
        _prices = FetchRequest(
            sortDescriptors: [],
            predicate: household.map { NSPredicate(format: "store.household == %@", $0) } ?? NSPredicate(value: false)
        )
    }

    private var shoppingStore: Store? {
        stores.first { $0.uuid?.uuidString == shoppingStoreID }
    }

    private var toBuy: [Item] { items.filter { !$0.isChecked } }

    private var inBasket: [Item] {
        items.filter(\.isChecked).sorted { ($0.checkedAt ?? .distantPast) > ($1.checkedAt ?? .distantPast) }
    }

    private var suggestions: [Product] {
        let onList = Set(toBuy.compactMap(\.product))
        return list.household?.products(matching: newItemName, limit: 6)
            .filter { !onList.contains($0) && $0.normalizedName != ProductName.normalized(newItemName) }
            .prefix(3)
            .map(\.self) ?? []
    }

    var body: some View {
        List {
            Section {
                ForEach(toBuy, id: \.objectID) { item in
                    itemRow(item)
                }
                newItemRow
                ForEach(suggestions, id: \.objectID) { product in
                    Button {
                        list.add(product)
                        context.saveIfNeeded()
                        newItemName = ""
                    } label: {
                        Label(product.name ?? "", systemImage: "plus.circle")
                            .foregroundStyle(list.color)
                    }
                }
            } footer: {
                if let shoppingStore, !toBuy.isEmpty {
                    let total = StoreTotal(items: toBuy, at: shoppingStore)
                    Group {
                        if total.pricedCount == total.itemCount {
                            Text("About \(Money.format(total.amountMinor)) at \(shoppingStore.name ?? "")")
                        } else if total.pricedCount > 0 {
                            Text("About \(Money.format(total.amountMinor)) for \(total.pricedCount) of \(total.itemCount) items at \(shoppingStore.name ?? "")")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if !inBasket.isEmpty {
                Section(isExpanded: $isBasketExpanded) {
                    ForEach(inBasket, id: \.objectID) { item in
                        itemRow(item)
                    }
                } header: {
                    basketHeader
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(list.name ?? "")
        .navigationSubtitle(subtitle)
        .tint(list.color)
        .toolbar { toolbar }
        .sheet(isPresented: $isEditingInfo) {
            ListEditor(list: list)
        }
        .sheet(isPresented: $isAddingStore) {
            if let household = list.household {
                StoreEditor(household: household)
            }
        }
        .sheet(item: $pricing) { target in
            PriceSheet(target: target)
        }
        .sheet(isPresented: $isComparing) {
            CompareView(list: list)
        }
        .sheet(item: $finishedTrip) { finished in
            TripSummaryView(trip: finished.trip)
        }
        #if DEBUG
        .task {
            if DebugLaunch.opensComparison { isComparing = true }
        }
        #endif
        .confirmationDialog("Clear the basket?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear \(inBasket.count) Items", role: .destructive, action: clearBasket)
        }
        .alert("Delete “\(list.name ?? "")”?", isPresented: $isConfirmingDeletion) {
            Button("Delete", role: .destructive, action: deleteList)
        } message: {
            Text("This will delete everything on the list.")
        }
    }

    private var subtitle: String {
        guard let shoppingStore else { return "" }
        let basket = StoreTotal(items: inBasket, at: shoppingStore)
        guard basket.amountMinor > 0 else { return shoppingStore.name ?? "" }
        return String(localized: "\(shoppingStore.name ?? "") · \(Money.format(basket.amountMinor)) in basket")
    }

    private func itemRow(_ item: Item) -> some View {
        ItemRow(
            item: item,
            tint: list.color,
            store: shoppingStore,
            price: shoppingStore.flatMap { item.product?.latestPrice(at: $0) },
            onToggle: { toggle(item) },
            onEditPrice: { editPrice(of: item) }
        )
    }

    private var newItemRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.title2)
                .foregroundStyle(Color(.quaternaryLabel))
                .accessibilityHidden(true)
            TextField("New Item", text: $newItemName)
                .focused($isAddingItem)
                .submitLabel(.next)
                .onSubmit(addItem)
        }
    }

    private var basketHeader: some View {
        HStack {
            Button {
                withAnimation { isBasketExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("In Basket")
                    Text(inBasket.count, format: .number).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isBasketExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button("Clear") { isConfirmingClear = true }
                .font(.subheadline)
        }
        .font(.headline)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if stores.count > 1 && !isAddingItem {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Compare Stores", systemImage: "chart.bar.xaxis") { isComparing = true }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isAddingItem {
                Button("Done") { isAddingItem = false }
            } else {
                Menu("More", systemImage: "ellipsis") {
                    Button("Show List Info", systemImage: "info.circle") { isEditingInfo = true }
                    Button("Compare Stores", systemImage: "chart.bar.xaxis") { isComparing = true }
                    Button("Clear Basket", systemImage: "basket") { isConfirmingClear = true }
                        .disabled(inBasket.isEmpty)
                    Divider()
                    Button("Delete List", systemImage: "trash", role: .destructive) { isConfirmingDeletion = true }
                }
            }
        }
        ToolbarItem(placement: .bottomBar) {
            Button {
                isAddingItem = true
            } label: {
                Label("New Item", systemImage: "plus.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .fontWeight(.semibold)
            }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        if shoppingStore != nil && !inBasket.isEmpty {
            ToolbarItem(placement: .bottomBar) {
                Button("Finish Shopping", action: finishShopping)
                    .buttonStyle(.glassProminent)
            }
        }
        ToolbarItem(placement: .bottomBar) {
            Menu {
                Picker("Shopping At", selection: $shoppingStoreID) {
                    Text("Not Shopping").tag("")
                    ForEach(stores, id: \.objectID) { store in
                        Label(store.name ?? "", systemImage: "storefront").tag(store.uuid?.uuidString ?? "")
                    }
                }
                Divider()
                Button("New Store…", systemImage: "plus") { isAddingStore = true }
            } label: {
                Label(shoppingStore?.name ?? String(localized: "Shopping At…"), systemImage: "storefront")
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    /// Ticking an item off while shopping confirms its price here, or asks for
    /// one if this store has none yet.
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

    private func finishShopping() {
        guard let store = shoppingStore,
              let trip = list.finishShopping(at: store, stores: Array(stores)) else { return }
        context.saveIfNeeded()
        shoppingStoreID = ""
        finishedTrip = FinishedTrip(trip: trip)
    }

    private func editPrice(of item: Item) {
        guard let store = shoppingStore, let product = item.product else { return }
        pricing = PricingTarget(product: product, store: store)
    }

    private func addItem() {
        guard list.addItem(named: newItemName) != nil else {
            // Returning on an empty row ends entry, as in Reminders.
            isAddingItem = false
            return
        }
        context.saveIfNeeded()
        newItemName = ""
        isAddingItem = true
    }

    private func clearBasket() {
        for item in inBasket {
            context.delete(item)
        }
        context.saveIfNeeded()
    }

    private func deleteList() {
        dismiss()
        context.delete(list)
        context.saveIfNeeded()
    }
}

private struct FinishedTrip: Identifiable {
    let trip: Trip
    var id: NSManagedObjectID { trip.objectID }
}

private struct ItemRow: View {
    @ObservedObject var item: Item
    let tint: Color
    let store: Store?
    let price: Price?
    let onToggle: () -> Void
    let onEditPrice: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? tint : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
                Text(item.displayName)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
                trailing
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(item.isChecked ? Text("In basket") : Text("To buy"))
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .contextMenu {
            Button("Increase Quantity", systemImage: "plus") { changeQuantity(by: 1) }
            Button("Decrease Quantity", systemImage: "minus") { changeQuantity(by: -1) }
                .disabled(item.quantity <= 1)
            if store != nil {
                Button(price == nil ? "Add Price…" : "Edit Price…", systemImage: "tag", action: onEditPrice)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if store != nil {
            if let price {
                VStack(alignment: .trailing) {
                    Text(Money.format(price.amountMinor * Int64(item.quantity)))
                    if item.quantity > 1 {
                        Text("\(item.quantity) × \(Money.format(price.amountMinor))")
                            .font(.caption)
                    }
                }
                .monospacedDigit()
                .foregroundStyle(.secondary)
            } else {
                Button("Add Price", action: onEditPrice)
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
        } else if item.quantity > 1 {
            Text("×\(item.quantity)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func changeQuantity(by delta: Int16) {
        item.quantity = max(1, item.quantity + delta)
        item.managedObjectContext?.saveIfNeeded()
    }

    private func delete() {
        let context = item.managedObjectContext
        context?.delete(item)
        context?.saveIfNeeded()
    }
}

#Preview {
    let persistence = PersistenceController.preview
    NavigationStack {
        ListDetailView(list: persistence.ensureHousehold().addList())
    }
    .environment(\.managedObjectContext, persistence.viewContext)
}
