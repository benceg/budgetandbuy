import CoreData
import MapKit
import SwiftUI

/// A shop: where it is, how long it takes to get there, every price seen
/// there, and what it doesn't sell.
struct ShopDetailView: View {
    @ObservedObject var store: Store
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    // Fetched so the view refreshes whenever a price here changes.
    @FetchRequest private var prices: FetchedResults<Price>
    @State private var isEditing = false
    @State private var pricing: PricingTarget?

    init(store: Store) {
        self.store = store
        _prices = FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "store == %@", store), animation: .default)
    }

    /// The newest record for each product, by name.
    private var sightings: [Price] {
        Dictionary(grouping: prices.filter { $0.product != nil }) { $0.product!.objectID }
            .values
            .compactMap { $0.max(by: Price.isOlder) }
            .sorted { ($0.product?.title ?? "").localizedStandardCompare($1.product?.title ?? "") == .orderedAscending }
    }

    private var currentPrices: [Price] { sightings.filter { !$0.isUnavailable } }
    private var notSold: [Price] { sightings.filter(\.isUnavailable) }

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                if currentPrices.isEmpty {
                    Text("Prices appear here as you tick things off while shopping at \(store.name ?? "").")
                        .foregroundStyle(Color.inkSecondary)
                }
                ForEach(currentPrices, id: \.objectID) { price in
                    Button {
                        if let product = price.product { pricing = PricingTarget(product: product, store: store) }
                    } label: {
                        ShopPriceRow(price: price)
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
            } header: {
                SectionHeading(title: "Prices", detail: currentPrices.isEmpty ? nil : currentPrices.count.formatted())
                    .textCase(nil)
            }
            .onSurface()

            if !notSold.isEmpty {
                Section {
                    ForEach(notSold, id: \.objectID) { note in
                        HStack(spacing: 12) {
                            ProductIcon(product: note.product)
                                .font(.title3)
                                .foregroundStyle(Color.inkSecondary)
                                .frame(width: 30)
                            Text(note.product?.title ?? "")
                                .foregroundStyle(Color.inkSecondary)
                            Spacer()
                        }
                        .swipeActions {
                            Button("Sold Here", systemImage: "checkmark") {
                                if let product = note.product {
                                    store.markAvailable(product)
                                    context.saveIfNeeded()
                                }
                            }
                            .tint(.brand)
                        }
                    }
                } header: {
                    SectionHeading(title: "Not sold here", detail: notSold.count.formatted())
                        .textCase(nil)
                } footer: {
                    Text("Swipe left on one if they start selling it.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .onSurface()
            }
        }
        .themedList()
        .navigationTitle(store.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            StoreEditor(store: store) { dismiss() }
        }
        .sheet(item: $pricing) { target in
            PriceSheet(target: target)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            Map(initialPosition: .region(MKCoordinateRegion(center: store.coordinate, latitudinalMeters: 700, longitudinalMeters: 700)), interactionModes: []) {
                Marker(store.name ?? "", monogram: Text(String((store.name ?? "").prefix(1))), coordinate: store.coordinate)
                    .tint(store.color)
            }
            .frame(height: 140)
            HStack(spacing: 14) {
                StoreBadge(store: store, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name ?? "")
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                    if let fullAddress = store.fullAddress {
                        Text(fullAddress)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    ShopJourney(store: store)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
            }
            .padding(16)
        }
        .background(Color.surface)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }
}

private struct ShopPriceRow: View {
    @ObservedObject var price: Price

    var body: some View {
        HStack(spacing: 12) {
            ProductIcon(product: price.product)
                .font(.title3)
                .foregroundStyle(Color.ink)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(price.product?.title ?? "")
                    .foregroundStyle(Color.ink)
                if let seen = price.createdAt {
                    Text("Seen \(Text(seen, format: .relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(price.amountMinor))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                if let size = price.product?.size {
                    Text(size.unitPrice(of: price.amountMinor))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .contentShape(.rect)
    }
}
