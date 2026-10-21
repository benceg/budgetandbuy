import CoreData
import SwiftUI

enum ListPage: String, CaseIterable, Hashable {
    case items, plan, budget

    var title: LocalizedStringResource {
        switch self {
        case .items: "Items"
        case .plan: "Where to Shop"
        case .budget: "Budget"
        }
    }
}

/// A list, in three views: what to buy, where to buy it, and what it'll cost.
/// The bottom button takes you shopping, and back out again.
struct ListScreen: View {
    @ObservedObject var list: ShoppingList
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    // Fetched separately, so ticking or unticking moves an item between the
    // two and the screen updates; a single fetch doesn't notice the change.
    @FetchRequest private var toBuyResults: FetchedResults<Item>
    @FetchRequest private var basketResults: FetchedResults<Item>
    @FetchRequest private var stores: FetchedResults<Store>
    // Fetched so totals and row prices refresh whenever any price changes.
    @FetchRequest private var prices: FetchedResults<Price>
    /// The shop you're in, per device and shared by all lists.
    @AppStorage("shoppingStoreID") private var shoppingStoreID = ""
    @AppStorage("groupsByAisle") private var groupsByAisle = true
    @State private var page: ListPage = .items
    @State private var isEditingInfo = false
    @State private var isChoosingShop = false
    @State private var isConfirmingClear = false
    @State private var isConfirmingDeletion = false
    @State private var finishedTrip: FinishedTrip?

    init(list: ShoppingList) {
        self.list = list
        _toBuyResults = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)],
            predicate: NSPredicate(format: "list == %@ AND isChecked == NO", list),
            animation: .default
        )
        _basketResults = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "checkedAt", ascending: false)],
            predicate: NSPredicate(format: "list == %@ AND isChecked == YES", list),
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

    /// Alphabetical, like the aisles they're grouped into.
    private var toBuy: [Item] { toBuyResults.sorted(by: Item.alphabetically) }
    private var inBasket: [Item] { Array(basketResults) }
    private var items: [Item] { toBuy + inBasket }

    var body: some View {
        Group {
            switch page {
            case .items:
                ItemsPage(list: list, toBuy: toBuy, inBasket: inBasket, stores: Array(stores), shoppingStore: shoppingStore)
            case .plan:
                PlanPage(list: list, items: toBuy.isEmpty ? items : toBuy, stores: Array(stores)) { store in
                    shoppingStoreID = store.uuid?.uuidString ?? ""
                    withAnimation { page = .items }
                }
            case .budget:
                BudgetPage(list: list, items: items, stores: Array(stores), shoppingStore: shoppingStore)
            }
        }
        .safeAreaBar(edge: .top) {
            ChipPicker(options: ListPage.allCases.map { ($0, $0.title) }, selection: $page)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .safeAreaBar(edge: .bottom) {
            if page == .items, !items.isEmpty {
                shoppingBar
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        #if DEBUG
        .background {
            if let points = DebugLaunch.scrollAnchor { DebugScrollOffset(points: points) }
        }
        #endif
        .navigationTitle(list.name ?? "")
        .navigationSubtitle(subtitle)
        // A large title collapses as you scroll, which changes the space under
        // the pinned page tabs; on short pages that fed back into the scroll
        // position and the screen jittered. A fixed title keeps it still.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $isEditingInfo) {
            ListEditor(list: list)
        }
        .sheet(isPresented: $isChoosingShop) {
            if let household = list.household {
                StartShoppingSheet(household: household, items: toBuy, stores: Array(stores), selectedID: $shoppingStoreID)
            }
        }
        .sheet(item: $finishedTrip) { finished in
            TripSummaryView(trip: finished.trip)
        }
        .onChange(of: liveActivityState, initial: true) { _, state in
            ShoppingActivityController.shared.sync(liveActivityAttributes, state: state)
        }
        .confirmationDialog("Clear the basket?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear \(inBasket.count) Items", role: .destructive, action: clearBasket)
        } message: {
            Text("This removes them from the list without recording a shop.")
        }
        .alert("Delete “\(list.name ?? "")”?", isPresented: $isConfirmingDeletion) {
            Button("Delete", role: .destructive, action: deleteList)
        } message: {
            Text("This will delete everything on the list. Prices you’ve recorded are kept.")
        }
        #if DEBUG
        .onAppear {
            if let debugPage = DebugLaunch.page { page = debugPage }
        }
        #endif
    }

    private var subtitle: String {
        guard let shoppingStore else {
            let count = toBuy.count
            return count == 0 ? "" : count == 1 ? String(localized: "1 item to buy") : String(localized: "\(count) items to buy")
        }
        return String(localized: "Shopping at \(shoppingStore.name ?? "")")
    }

    @ViewBuilder
    private var shoppingBar: some View {
        if let shoppingStore {
            HStack(spacing: 12) {
                Menu {
                    shopMenu
                } label: {
                    HStack(spacing: 10) {
                        StoreBadge(store: shoppingStore, size: 36)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(Money.format(StoreTotal(items: inBasket, at: shoppingStore).amountMinor))
                                .font(.headline)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(inBasket.count == 1 ? "1 in basket" : "\(inBasket.count) in basket")
                                .font(.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        .foregroundStyle(Color.ink)
                    }
                    .padding(.leading, 6)
                    .contentShape(.rect)
                }
                .accessibilityLabel("Shopping at \(shoppingStore.name ?? ""). Change shop")

                Button("Finish Shopping", action: finishShopping)
                    .buttonStyle(.primary)
                    .disabled(inBasket.isEmpty)
            }
            .padding(8)
            .glassEffect(.regular, in: .capsule)
        } else {
            Button {
                isChoosingShop = true
            } label: {
                Label("Start Shopping", systemImage: "basket")
            }
            .buttonStyle(.primary)
        }
    }

    @ViewBuilder
    private var shopMenu: some View {
        Picker("Shopping At", selection: $shoppingStoreID) {
            ForEach(stores, id: \.objectID) { store in
                Text(store.name ?? "").tag(store.uuid?.uuidString ?? "")
            }
        }
        Divider()
        Button("Stop Shopping", systemImage: "xmark") { shoppingStoreID = "" }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("More", systemImage: "ellipsis") {
                Button("Rename List…", systemImage: "pencil") { isEditingInfo = true }
                Toggle("Group by Aisle", systemImage: "square.grid.2x2", isOn: $groupsByAisle)
                Button("Clear Basket", systemImage: "basket") { isConfirmingClear = true }
                    .disabled(inBasket.isEmpty)
                Divider()
                Button("Delete List", systemImage: "trash", role: .destructive) { isConfirmingDeletion = true }
            }
        }
    }

    /// What the Live Activity shows, or nil when you're not shopping from this list.
    private var liveActivityState: ShoppingActivityAttributes.ContentState? {
        guard let shoppingStore, !items.isEmpty else { return nil }
        let toBuyInOrder = ProductCategory.aisles(of: toBuy).flatMap(\.items)
        return ShoppingActivityAttributes.ContentState(
            basketMinor: StoreTotal(items: inBasket, at: shoppingStore).amountMinor,
            basketCount: inBasket.count,
            remainingCount: toBuy.count,
            upNext: toBuyInOrder.prefix(3).map(\.displayName)
        )
    }

    private var liveActivityAttributes: ShoppingActivityAttributes {
        ShoppingActivityAttributes(
            listID: list.objectID.uriRepresentation().absoluteString,
            listName: list.name ?? "",
            storeName: shoppingStore?.name ?? "",
            colorName: shoppingStore?.colorName ?? "sage"
        )
    }

    private func finishShopping() {
        guard let store = shoppingStore,
              let trip = list.finishShopping(at: store, stores: Array(stores)) else { return }
        context.saveIfNeeded()
        shoppingStoreID = ""
        finishedTrip = FinishedTrip(trip: trip)
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
