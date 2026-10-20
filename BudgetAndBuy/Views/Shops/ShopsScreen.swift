import CoreData
import SwiftUI

/// The shops the household uses, each with the prices it has collected.
struct ShopsScreen: View {
    @ObservedObject var household: Household
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var stores: FetchedResults<Store>
    @AppStorage(StoreArrivalMonitor.enabledKey) private var noticesArrivals = false
    @State private var isAdding = false
    @State private var path = NavigationPath()

    init(household: Household) {
        self.household = household
        _stores = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))],
            predicate: NSPredicate(format: "household == %@", household),
            animation: .default
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if stores.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            EmptyState(
                                systemImage: "storefront",
                                title: "Which shops do you use?",
                                message: "Add the supermarkets and local shops you buy from. Each one keeps its own prices, which you add as you shop, so you can see where your list costs least."
                            ) {
                                Button("Add a Shop") { isAdding = true }
                                    .buttonStyle(.primary)
                            }
                            .card()
                        }
                        .padding()
                    }
                    .canvasBackground()
                } else {
                    shopList
                }
            }
            .navigationTitle("Shops")
            .toolbar {
                if !stores.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add Shop") { isAdding = true }
                    }
                }
            }
            .navigationDestination(for: Store.self) { store in
                ShopDetailView(store: store)
            }
            .sheet(isPresented: $isAdding) {
                NavigationStack {
                    AddShopView(household: household) { store in
                        isAdding = false
                        path.append(store)
                    }
                }
            }
            #if DEBUG
            .onAppear {
                if DebugLaunch.opensAddShop { isAdding = true }
            }
            #endif
        }
    }

    private var shopList: some View {
        List {
            Section {
                ForEach(stores, id: \.objectID) { store in
                    NavigationLink(value: store) {
                        ShopRow(store: store)
                    }
                }
                Button { isAdding = true } label: {
                    Label("Add a Shop", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.forestInk)
                }
            } footer: {
                Text("Each shop keeps its own prices. Add the ones you choose between, even if you rarely go, to see what a longer trip would save.")
                    .foregroundStyle(Color.inkSecondary)
            }
            .onSurface()

            if stores.contains(where: \.hasLocation) {
                Section {
                    Toggle(isOn: Binding(
                        get: { noticesArrivals },
                        set: { enabled in Task { await StoreArrivalMonitor.shared.setEnabled(enabled) } }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start shopping when I arrive")
                                .foregroundStyle(Color.ink)
                            Text("Your iPhone notices when you reach one of these shops and gets your list ready. Your location stays on your iPhone.")
                                .font(.footnote)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                    .tint(.forest)
                }
                .onSurface()
            }
        }
        .themedList()
    }
}

private struct ShopRow: View {
    @ObservedObject var store: Store
    @FetchRequest private var prices: FetchedResults<Price>

    init(store: Store) {
        self.store = store
        _prices = FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "store == %@", store))
    }

    private var priceSummary: String {
        let count = Set(prices.compactMap { $0.product?.objectID }).count
        return switch count {
        case 0: String(localized: "No prices yet")
        case 1: String(localized: "1 price")
        default: String(localized: "\(count) prices")
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            StoreBadge(store: store, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.name ?? "")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text("\(Image(systemName: store.travel.symbolName)) \(store.journey) · \(priceSummary)")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.vertical, 6)
    }
}
