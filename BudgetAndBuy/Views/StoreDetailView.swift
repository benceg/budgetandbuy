import CoreData
import SwiftUI

/// A store's journey and the current price of everything seen there.
struct StoreDetailView: View {
    @ObservedObject var store: Store
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    // Fetched so the view refreshes whenever a price here changes.
    @FetchRequest private var prices: FetchedResults<Price>
    @State private var isEditingInfo = false
    @State private var isConfirmingDeletion = false
    @State private var pricing: PricingTarget?

    init(store: Store) {
        self.store = store
        _prices = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "store == %@", store),
            animation: .default
        )
    }

    private var currentPrices: [Price] {
        Dictionary(grouping: prices.filter { $0.product != nil }) { $0.product!.objectID }
            .values
            .compactMap { $0.max(by: Price.isOlder) }
            .sorted { ($0.product?.title ?? "").localizedStandardCompare($1.product?.title ?? "") == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Getting There") {
                    Label(store.journey, systemImage: store.travel.symbolName)
                }
                if store.distanceKm > 0 {
                    LabeledContent(
                        "Distance",
                        value: Measurement(value: store.distanceKm, unit: UnitLength.kilometers),
                        format: .measurement(width: .abbreviated, usage: .road)
                    )
                }
            }

            Section("Prices") {
                if currentPrices.isEmpty {
                    Text("Prices you add while shopping here appear here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(currentPrices, id: \.objectID) { price in
                    Button {
                        if let product = price.product {
                            pricing = PricingTarget(product: product, store: store)
                        }
                    } label: {
                        HStack {
                            Text(price.product?.title ?? "")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(Money.format(price.amountMinor))
                                    .monospacedDigit()
                                if let size = price.product?.size {
                                    Text(size.unitPrice(of: price.amountMinor))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let seen = price.createdAt {
                                    Text(seen, format: .relative(presentation: .named))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Forget", systemImage: "trash", role: .destructive) {
                            if let product = price.product {
                                store.forgetPrices(of: product)
                                context.saveIfNeeded()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(store.name ?? "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Show Store Info", systemImage: "info.circle") { isEditingInfo = true }
                    Divider()
                    Button("Delete Store", systemImage: "trash", role: .destructive) { isConfirmingDeletion = true }
                }
            }
        }
        .sheet(isPresented: $isEditingInfo) {
            StoreEditor(store: store)
        }
        .sheet(item: $pricing) { target in
            PriceSheet(target: target)
        }
        .alert("Delete “\(store.name ?? "")”?", isPresented: $isConfirmingDeletion) {
            Button("Delete", role: .destructive, action: deleteStore)
        } message: {
            Text("This will also delete every price recorded there.")
        }
    }

    private func deleteStore() {
        dismiss()
        context.delete(store)
        context.saveIfNeeded()
    }
}
