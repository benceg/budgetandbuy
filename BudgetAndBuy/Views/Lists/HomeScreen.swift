import CoreData
import SwiftUI

/// Every household, each with its lists. Opening a list makes its household
/// the current one, and the app reopens into that list next time.
struct HomeScreen: View {
    let households: [Household]
    @Binding var selectedHouseholdID: String
    @Binding var tab: AppTab

    @Environment(\.managedObjectContext) private var context
    /// The list open when the app was last used, reopened at launch.
    @AppStorage("lastListID") private var lastListID = ""
    // Fetched so list estimates refresh when prices change.
    @FetchRequest(sortDescriptors: []) private var prices: FetchedResults<Price>
    @State private var path = NavigationPath()
    @State private var newListHousehold: Household?
    @State private var isAddingHousehold = false
    @State private var listPendingDeletion: ShoppingList?
    @State private var hasRestored = false

    private var ownHouseholds: [Household] { households.filter { !$0.isSharedWithMe } }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(HouseholdSelection.sorted(households), id: \.objectID) { household in
                    HouseholdSection(
                        household: household,
                        onOpenList: { list in path.append(list) },
                        onNewList: { newListHousehold = household },
                        onAddShops: {
                            selectedHouseholdID = household.uuid?.uuidString ?? ""
                            tab = .shops
                        },
                        onDelete: { list in
                            if list.items?.isEmpty ?? true { delete(list) } else { listPendingDeletion = list }
                        }
                    )
                }

                Section {
                    Button {
                        isAddingHousehold = true
                    } label: {
                        Label("New Household", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.brandInk)
                    }
                } footer: {
                    Text("Keep separate households for separate homes, such as someone you care for. Each is shared only with the people you invite to it.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .onSurface()
            }
            .themedList()
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Household") { isAddingHousehold = true }
                }
            }
            .navigationDestination(for: ShoppingList.self) { list in
                ListScreen(list: list)
                    .onAppear { open(list) }
            }
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .navigationDestination(for: Household.self) { household in
                HouseholdSettingsScreen(household: household, isOnlyHousehold: ownHouseholds == [household])
            }
            .onChange(of: path.count) { _, count in
                if count == 0 { lastListID = "" }
            }
            .task { restore() }
            .sheet(item: $newListHousehold) { household in
                ListEditor(household: household) { list in
                    path.append(list)
                }
            }
            .sheet(isPresented: $isAddingHousehold) {
                NewHouseholdSheet(households: households) { household in
                    selectedHouseholdID = household.uuid?.uuidString ?? ""
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
        }
    }

    /// Opening a list makes its household current, for Shops and Savings,
    /// and remembers it for next launch.
    private func open(_ list: ShoppingList) {
        if let id = list.household?.uuid?.uuidString { selectedHouseholdID = id }
        lastListID = list.uuid?.uuidString ?? ""
    }

    /// Reopens the list that was open last time, once, at launch.
    private func restore() {
        guard !hasRestored else { return }
        hasRestored = true
        #if DEBUG
        if openDebugList() { return }
        #endif
        guard !lastListID.isEmpty,
              let list = households.lazy.flatMap({ $0.lists ?? [] }).first(where: { $0.uuid?.uuidString == lastListID })
        else { return }
        path.append(list)
    }

    #if DEBUG
    private func openDebugList() -> Bool {
        let current = HouseholdSelection.preferred(from: households, selectedID: selectedHouseholdID)
        if DebugLaunch.opensHouseholdSettings, let current {
            path.append(current)
            return true
        }
        let lists = (current?.lists ?? []).sorted { $0.sortOrder < $1.sortOrder }
        guard let list = DebugLaunch.opensLastList ? lists.last : DebugLaunch.opensFirstList ? lists.first : nil else { return false }
        path.append(list)
        if DebugLaunch.opensFirstItem {
            let items = (list.items ?? []).sorted(by: DebugLaunch.opensLastList ? Item.alphabetically : Item.isOlder)
            if let item = items.first { path.append(item) }
        }
        return true
    }
    #endif

    private func delete(_ list: ShoppingList) {
        context.delete(list)
        context.saveIfNeeded()
    }
}

extension Household: Identifiable {}

/// A household's heading and its lists, alphabetically.
private struct HouseholdSection: View {
    @ObservedObject var household: Household
    let onOpenList: (ShoppingList) -> Void
    let onNewList: () -> Void
    let onAddShops: () -> Void
    let onDelete: (ShoppingList) -> Void

    @FetchRequest private var lists: FetchedResults<ShoppingList>
    @FetchRequest private var stores: FetchedResults<Store>

    init(household: Household, onOpenList: @escaping (ShoppingList) -> Void, onNewList: @escaping () -> Void, onAddShops: @escaping () -> Void, onDelete: @escaping (ShoppingList) -> Void) {
        self.household = household
        self.onOpenList = onOpenList
        self.onNewList = onNewList
        self.onAddShops = onAddShops
        self.onDelete = onDelete
        let inHousehold = NSPredicate(format: "household == %@", household)
        _lists = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))],
            predicate: inHousehold,
            animation: .default
        )
        _stores = FetchRequest(sortDescriptors: [], predicate: inHousehold)
    }

    var body: some View {
        Section {
            ForEach(lists, id: \.objectID) { list in
                NavigationLink(value: list) {
                    ListRow(list: list, stores: Array(stores))
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(list) }
                }
            }
            Button(action: onNewList) {
                Label("New List", systemImage: "plus.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brandInk)
            }
            if stores.isEmpty {
                Button(action: onAddShops) {
                    Label("Add the shops this household uses", systemImage: "storefront")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        } header: {
            HStack(spacing: 10) {
                Image(systemName: "house.fill")
                    .font(.footnote)
                    .foregroundStyle(ListAppearance.foreground(named: household.colorName))
                    .frame(width: 28, height: 28)
                    .background(ListAppearance.color(named: household.colorName), in: .circle)
                VStack(alignment: .leading, spacing: 0) {
                    Text(household.name ?? "")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    if household.isSharedWithMe {
                        Text("Shared with you")
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                Spacer()
                NavigationLink(value: household) {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: 44, height: 36)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings for \(household.name ?? "")")
            }
            .textCase(nil)
        }
        .onSurface()
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
            ListIcon(symbolName: list.symbol, color: list.color, foreground: list.foreground, size: 40)
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

