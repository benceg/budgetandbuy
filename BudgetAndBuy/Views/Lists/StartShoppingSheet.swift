import CoreData
import SwiftUI

/// Asks which shop you're in, showing what the list costs at each.
struct StartShoppingSheet: View {
    let household: Household
    let items: [Item]
    let stores: [Store]
    @Binding var selectedID: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let comparison = StoreComparison(items: items, stores: stores)
        let cheapest = comparison.options.first { $0.pricedCount > 0 }?.store
        NavigationStack {
            List {
                Section {
                    ForEach(comparison.options) { option in
                        Button {
                            start(at: option.store)
                        } label: {
                            ShopChoiceRow(
                                option: option,
                                itemCount: comparison.itemCount,
                                notSoldCount: comparison.unavailableItems(at: option.store).count,
                                isCheapest: option.store == cheapest && stores.count > 1,
                                isClosest: option.store == comparison.nearest && stores.count > 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink {
                        AddShopView(household: household, canCancel: false) { store in start(at: store) }
                    } label: {
                        Label("Add a Shop", systemImage: "plus.circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.brandInk)
                    }
                } footer: {
                    Text("Tick things off as they go in your basket. The first time you buy something at a shop, you’ll be asked what it cost, so next time you can compare.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .onSurface()
            }
            .themedList()
            .navigationTitle("Where Are You Shopping?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func start(at store: Store) {
        selectedID = store.uuid?.uuidString ?? ""
        dismiss()
    }
}

private struct ShopChoiceRow: View {
    let option: StoreComparison.Option
    let itemCount: Int
    let notSoldCount: Int
    let isCheapest: Bool
    let isClosest: Bool

    var body: some View {
        HStack(spacing: 12) {
            StoreBadge(store: option.store, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(option.store.name ?? "")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                HStack(spacing: 6) {
                    Text("\(Image(systemName: option.store.travel.symbolName)) \(option.store.journey)")
                        .foregroundStyle(Color.inkSecondary)
                    if isCheapest { Tag(text: String(localized: "Cheapest"), foreground: .brandInk, background: .brandPale) }
                    if isClosest { Tag(text: String(localized: "Closest")) }
                }
                .font(.subheadline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if option.pricedCount > 0 {
                    Text(Money.format(option.totalMinor))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                    Text("\(option.pricedCount) of \(itemCount) priced")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                } else {
                    Text("No prices yet")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                if notSoldCount > 0 {
                    Text(notSoldCount == 1 ? "1 not sold here" : "\(notSoldCount) not sold here")
                        .font(.caption)
                        .foregroundStyle(Color.apricot)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
