import CoreData
import SwiftUI

struct ListsView: View {
    @ObservedObject var household: Household
    let households: [Household]
    @Binding var selectedID: String
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var lists: FetchedResults<ShoppingList>
    @FetchRequest private var stores: FetchedResults<Store>
    @FetchRequest private var trips: FetchedResults<Trip>
    @State private var isAddingList = false
    @State private var isAddingStore = false
    @State private var isShowingHousehold = false
    @State private var listPendingDeletion: ShoppingList?
    @State private var path = NavigationPath()

    init(household: Household, households: [Household], selectedID: Binding<String>) {
        self.household = household
        self.households = households
        _selectedID = selectedID
        _lists = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "sortOrder", ascending: true)],
            predicate: NSPredicate(format: "household == %@", household),
            animation: .default
        )
        _trips = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "household == %@", household)
        )
        _stores = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))],
            predicate: NSPredicate(format: "household == %@", household),
            animation: .default
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !trips.isEmpty {
                    let stats = TripStats(trips: trips, period: .year)
                    Section {
                        NavigationLink(value: StatsRoute()) {
                            Grid(horizontalSpacing: 12) {
                                GridRow {
                                    StatTile(title: "Saved This Year", value: Money.format(stats.savedMinor), symbolName: "banknote.fill", color: .green)
                                    StatTile(title: "CO₂ Avoided", value: CarbonFormat.format(stats.carbonAvoidedKg), symbolName: "leaf.fill", color: .mint)
                                }
                            }
                        }
                        .navigationLinkIndicatorVisibility(.hidden)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if !lists.isEmpty {
                    Section("Lists") {
                        ForEach(lists, id: \.objectID) { list in
                            NavigationLink(value: list) {
                                ListRow(list: list)
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    if list.items?.isEmpty ?? true {
                                        delete(list)
                                    } else {
                                        listPendingDeletion = list
                                    }
                                }
                            }
                        }
                        .onMove(perform: move)
                    }
                }
                if !stores.isEmpty {
                    Section("Stores") {
                        ForEach(stores, id: \.objectID) { store in
                            NavigationLink(value: store) {
                                StoreRow(store: store)
                            }
                        }
                    }
                }
            }
            .navigationTitle(household.name ?? String(localized: "Lists"))
            .toolbarTitleMenu {
                if households.count > 1 {
                    Picker("Household", selection: $selectedID) {
                        ForEach(households, id: \.objectID) { household in
                            Text(household.name ?? "").tag(household.uuid?.uuidString ?? "")
                        }
                    }
                }
            }
            .navigationDestination(for: ShoppingList.self) { list in
                ListDetailView(list: list)
            }
            .navigationDestination(for: Store.self) { store in
                StoreDetailView(store: store)
            }
            .navigationDestination(for: StatsRoute.self) { _ in
                StatsView(household: household)
            }
            .overlay {
                if lists.isEmpty && stores.isEmpty {
                    ContentUnavailableView {
                        Label("No Lists", systemImage: "cart")
                    } description: {
                        Text("Lists you make appear here.")
                    } actions: {
                        Button("Add List") { isAddingList = true }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Household", systemImage: "person.2") { isShowingHousehold = true }
                }
                if !lists.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Menu("Add", systemImage: "plus") {
                        Button("New List", systemImage: "list.bullet") { isAddingList = true }
                        Button("New Store", systemImage: "storefront") { isAddingStore = true }
                    }
                }
            }
            #if DEBUG
            .task {
                if DebugLaunch.opensFirstList, let first = lists.first { path.append(first) }
                if DebugLaunch.opensStats { path.append(StatsRoute()) }
            }
            #endif
            .sheet(isPresented: $isAddingList) {
                ListEditor(household: household)
            }
            .sheet(isPresented: $isAddingStore) {
                StoreEditor(household: household)
            }
            .sheet(isPresented: $isShowingHousehold) {
                HouseholdView(household: household)
            }
            .alert(
                "Delete “\(listPendingDeletion?.name ?? "")”?",
                isPresented: Binding(
                    get: { listPendingDeletion != nil },
                    set: { if !$0 { listPendingDeletion = nil } }
                ),
                presenting: listPendingDeletion
            ) { list in
                Button("Delete", role: .destructive) { delete(list) }
            } message: { _ in
                Text("This will delete everything on the list.")
            }
        }
    }

    private func delete(_ list: ShoppingList) {
        context.delete(list)
        context.saveIfNeeded()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = Array(lists)
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, list) in reordered.enumerated() {
            list.sortOrder = Double(index)
        }
        context.saveIfNeeded()
    }
}

private struct ListRow: View {
    @ObservedObject var list: ShoppingList
    @FetchRequest private var remaining: FetchedResults<Item>

    init(list: ShoppingList) {
        self.list = list
        _remaining = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "list == %@ AND isChecked == NO", list)
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ListIcon(symbolName: list.symbol, color: list.color)
            Text(list.name ?? "")
            Spacer()
            Text(remaining.count, format: .number)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(remaining.count) to buy")
        }
    }
}

private struct StatsRoute: Hashable {}

private struct StoreRow: View {
    @ObservedObject var store: Store

    var body: some View {
        HStack(spacing: 12) {
            ListIcon(symbolName: "storefront.fill", color: store.color)
            VStack(alignment: .leading) {
                Text(store.name ?? "")
                Text("\(Image(systemName: store.travel.symbolName)) \(store.journey)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let persistence = PersistenceController.preview
    let household = persistence.ensureHousehold()
    ListsView(household: household, households: [household], selectedID: .constant(""))
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(\.persistence, persistence)
}
