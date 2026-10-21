import CoreData
import SwiftUI

/// The household's lists, with a glance at what's left on each.
struct ListsScreen: View {
    @ObservedObject var household: Household
    let households: [Household]
    @Binding var selectedHouseholdID: String
    @Binding var tab: AppTab

    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var lists: FetchedResults<ShoppingList>
    @FetchRequest private var stores: FetchedResults<Store>
    @FetchRequest private var trips: FetchedResults<Trip>
    // Fetched so estimates refresh when prices change.
    @FetchRequest private var prices: FetchedResults<Price>
    @State private var path = NavigationPath()
    @State private var isAddingList = false
    @State private var listPendingDeletion: ShoppingList?

    init(household: Household, households: [Household], selectedHouseholdID: Binding<String>, tab: Binding<AppTab>) {
        self.household = household
        self.households = households
        _selectedHouseholdID = selectedHouseholdID
        _tab = tab
        let inHousehold = NSPredicate(format: "household == %@", household)
        _lists = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "sortOrder", ascending: true)], predicate: inHousehold, animation: .default)
        _stores = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], predicate: inHousehold)
        _trips = FetchRequest(sortDescriptors: [], predicate: inHousehold)
        _prices = FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "store.household == %@", household))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !trips.isEmpty {
                    Section {
                        savingsSummary
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(lists, id: \.objectID) { list in
                        NavigationLink(value: list) {
                            ListRow(list: list, stores: Array(stores))
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                if list.items?.isEmpty ?? true { delete(list) } else { listPendingDeletion = list }
                            }
                        }
                    }
                    .onMove(perform: move)

                    Button {
                        isAddingList = true
                    } label: {
                        Label("New List", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.brandInk)
                    }
                } header: {
                    if !lists.isEmpty {
                        SectionHeading(title: "Your Lists")
                            .textCase(nil)
                    }
                }
                .onSurface()

                if stores.isEmpty {
                    Section {
                        ShopsPrompt { tab = .shops }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .themedList()
            .navigationTitle(household.name ?? String(localized: "Lists"))
            .toolbarTitleMenu {
                if households.count > 1 {
                    Picker("Household", selection: $selectedHouseholdID) {
                        ForEach(households, id: \.objectID) { household in
                            Text(household.name ?? "").tag(household.uuid?.uuidString ?? "")
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New List") { isAddingList = true }
                }
            }
            .navigationDestination(for: ShoppingList.self) { list in
                ListScreen(list: list)
            }
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .sheet(isPresented: $isAddingList) {
                ListEditor(household: household) { list in
                    path.append(list)
                }
            }
            .alert(
                "Delete “\(listPendingDeletion?.name ?? "")”?",
                isPresented: Binding(get: { listPendingDeletion != nil }, set: { if !$0 { listPendingDeletion = nil } }),
                presenting: listPendingDeletion
            ) { list in
                Button("Delete", role: .destructive) { delete(list) }
            } message: { _ in
                Text("This will delete everything on the list. Prices you’ve recorded are kept.")
            }
            #if DEBUG
            .task {
                if DebugLaunch.opensLastList {
                    try? await Task.sleep(for: .milliseconds(300))
                    if let last = lists.last { path.append(last) }
                }
                if DebugLaunch.opensFirstList, let first = lists.first {
                    path.append(first)
                    if DebugLaunch.opensFirstItem, let item = (first.items ?? []).sorted(by: Item.isOlder).first {
                        path.append(item)
                    }
                }
            }
            #endif
        }
    }

    private var savingsSummary: some View {
        let stats = TripStats(trips: trips, period: .month)
        return Button { tab = .savings } label: {
            HStack(spacing: 12) {
                SummaryTile(title: "Saved this month", value: Money.format(stats.savedMinor), systemImage: "sterlingsign", tint: .brandInk)
                SummaryTile(title: "CO₂ avoided", value: CarbonFormat.format(stats.carbonAvoidedKg), systemImage: "leaf", tint: .leaf)
            }
        }
        .buttonStyle(.plain)
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

/// A small figure with its label, for summaries.
struct SummaryTile: View {
    let title: LocalizedStringResource
    let value: String
    let systemImage: String
    var tint: Color = .brandInk

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Color.brandPale, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

private struct ListRow: View {
    @ObservedObject var list: ShoppingList
    let stores: [Store]
    @FetchRequest private var remaining: FetchedResults<Item>

    init(list: ShoppingList, stores: [Store]) {
        self.list = list
        self.stores = stores
        _remaining = FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "list == %@ AND isChecked == NO", list))
    }

    private var summary: String {
        guard !remaining.isEmpty else { return String(localized: "Nothing to buy") }
        let count = remaining.count == 1 ? String(localized: "1 item") : String(localized: "\(remaining.count) items")
        let estimate = ListEstimate(items: Array(remaining), stores: stores)
        guard estimate.pricedCount > 0 else { return count }
        return String(localized: "\(count) · about \(Money.format(estimate.totalMinor))")
    }

    var body: some View {
        HStack(spacing: 14) {
            ListIcon(symbolName: list.symbol, color: list.color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name ?? "")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Points someone without shops towards adding them, since comparisons and
/// prices need them.
private struct ShopsPrompt: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "storefront")
                    .font(.title3)
                    .foregroundStyle(Color.brandInk)
                    .frame(width: 44, height: 44)
                    .background(Color.brandPale, in: .circle)
                Text("Add the shops you use")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
            }
            Text("Budget & Buy remembers what things cost at each shop as you tick them off, then shows you where your list is cheapest.")
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Add a Shop", action: action)
                .buttonStyle(.secondary)
        }
        .card()
    }
}
