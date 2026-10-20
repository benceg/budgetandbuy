import CoreData
import SwiftUI

/// What a list would cost at each store, and whether a longer trip pays off.
struct CompareView: View {
    @ObservedObject var list: ShoppingList
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var stores: FetchedResults<Store>
    // Fetched so the comparison refreshes whenever a price changes.
    @FetchRequest private var prices: FetchedResults<Price>

    /// Prices older than this are flagged as possibly out of date.
    private static let staleAfter: TimeInterval = 30 * 24 * 60 * 60

    init(list: ShoppingList) {
        self.list = list
        let household = list.household
        _stores = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            predicate: household.map { NSPredicate(format: "household == %@", $0) } ?? NSPredicate(value: false)
        )
        _prices = FetchRequest(
            sortDescriptors: [],
            predicate: household.map { NSPredicate(format: "store.household == %@", $0) } ?? NSPredicate(value: false)
        )
    }

    /// What's left to buy, or the whole list once everything's in the basket.
    private var items: [Item] {
        let all = (list.items ?? []).sorted(by: Item.isOlder)
        let toBuy = all.filter { !$0.isChecked }
        return toBuy.isEmpty ? all : toBuy
    }

    var body: some View {
        let comparison = StoreComparison(items: items, stores: Array(stores))
        NavigationStack {
            Group {
                if stores.count < 2 {
                    ContentUnavailableView {
                        Label("Add Another Store", systemImage: "storefront")
                    } description: {
                        Text("Comparing needs at least two stores. Add them from your household’s home screen.")
                    }
                } else if comparison.options.allSatisfy({ $0.pricedCount == 0 }) {
                    ContentUnavailableView {
                        Label("No Prices Yet", systemImage: "tag")
                    } description: {
                        Text("Choose the store you’re in while shopping, and add prices as you tick things off.")
                    }
                } else {
                    comparisonList(comparison)
                }
            }
            .navigationTitle("Compare Stores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func comparisonList(_ comparison: StoreComparison) -> some View {
        List {
            Section {
                headline(comparison)
            }

            Section("Stores") {
                ForEach(comparison.options) { option in
                    OptionRow(
                        option: option,
                        itemCount: comparison.itemCount,
                        isNearest: option.store == comparison.nearest,
                        saving: comparison.saving(at: option.store),
                        extraCarbonKg: comparison.extraCarbonKg(at: option.store),
                        isStale: option.oldestPrice.map { $0 < .now - Self.staleAfter } ?? false
                    )
                }
            }

            if let split = comparison.split {
                Section {
                    NavigationLink {
                        SplitDetailView(split: split)
                    } label: {
                        SplitRow(split: split, itemCount: comparison.itemCount)
                    }
                } header: {
                    Text("Split Your Shop")
                } footer: {
                    Text("Buying each item wherever it’s cheaper.")
                }
            }

            if !comparison.unpriced.isEmpty {
                Section {
                    ForEach(comparison.unpriced, id: \.objectID) { item in
                        Text(item.displayName)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("No Prices Yet")
                } footer: {
                    Text("Add prices while you shop to include these.")
                }
            }
        }
    }

    @ViewBuilder
    private func headline(_ comparison: StoreComparison) -> some View {
        if let best = comparison.bestSaving, let nearest = comparison.nearest {
            VStack(alignment: .leading, spacing: 6) {
                Text("Save about \(Money.format(best.saving.amountMinor)) at \(best.option.store.name ?? "")")
                    .font(.title3.bold())
                Text(savingDetail(best.saving, nearest: nearest))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } else if let nearest = comparison.nearest {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(nearest.name ?? "") is your best bet")
                    .font(.title3.bold())
                Text("It’s the closest, and nowhere is cheaper for the items you’ve priced.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func savingDetail(_ saving: StoreComparison.Saving, nearest: Store) -> String {
        let items = String(localized: "Compared with \(nearest.name ?? "") on \(saving.commonCount) items")
        if saving.extraMinutes > 0 {
            return String(localized: "\(items), for \(saving.extraMinutes) more minutes each way.")
        }
        return String(localized: "\(items), and it’s no further away.")
    }
}

private struct OptionRow: View {
    let option: StoreComparison.Option
    let itemCount: Int
    let isNearest: Bool
    let saving: StoreComparison.Saving?
    let extraCarbonKg: Double?
    let isStale: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ListIcon(symbolName: "storefront.fill", color: option.store.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(option.store.name ?? "")
                Text("\(Image(systemName: option.store.travel.symbolName)) \(option.store.journey)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                comparisonLine
                    .font(.subheadline)
                if let extraCarbonKg, extraCarbonKg >= 0.05 {
                    Text("\(Image(systemName: "leaf")) +\(extraCarbonKg.formatted(.number.precision(.fractionLength(1)))) kg CO₂ per trip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(option.totalMinor))
                    .monospacedDigit()
                Text("\(option.pricedCount) of \(itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isStale {
                    Text("\(Image(systemName: "clock")) Old prices")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var comparisonLine: some View {
        if isNearest {
            Text("\(Image(systemName: "location")) Closest")
                .foregroundStyle(.secondary)
        } else if let saving {
            if saving.amountMinor > 0 {
                Text("\(Money.format(saving.amountMinor)) less on \(saving.commonCount) items")
                    .foregroundStyle(.green)
            } else if saving.amountMinor < 0 {
                Text("\(Money.format(-saving.amountMinor)) more on \(saving.commonCount) items")
                    .foregroundStyle(.secondary)
            } else {
                Text("Same price on \(saving.commonCount) items")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SplitRow: View {
    let split: StoreComparison.Split
    let itemCount: Int

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(split.first.name ?? "") + \(split.second.name ?? "")")
                Text("Buy \(split.firstItems.count) at \(split.first.name ?? "") and \(split.secondItems.count) at \(split.second.name ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(split.totalMinor))
                    .monospacedDigit()
                Text("\(split.pricedCount) of \(itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SplitDetailView: View {
    let split: StoreComparison.Split

    var body: some View {
        List {
            section(store: split.first, items: split.firstItems)
            section(store: split.second, items: split.secondItems)
        }
        .navigationTitle("Split Your Shop")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(store: Store, items: [Item]) -> some View {
        Section {
            ForEach(items, id: \.objectID) { item in
                HStack {
                    Text(item.displayName)
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let price = item.product?.latestPrice(at: store) {
                        Text(Money.format(price.amountMinor * Int64(item.quantity)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Label(store.name ?? "", systemImage: "storefront")
        }
    }
}
