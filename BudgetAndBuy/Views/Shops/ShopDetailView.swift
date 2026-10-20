import CoreData
import MapKit
import SwiftUI

/// A shop: where it is, how you get there, and every price seen there.
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

    private var currentPrices: [Price] {
        Dictionary(grouping: prices.filter { $0.product != nil }) { $0.product!.objectID }
            .values
            .compactMap { $0.max(by: Price.isOlder) }
            .sorted { ($0.product?.title ?? "").localizedStandardCompare($1.product?.title ?? "") == .orderedAscending }
    }

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
            if let coordinate = store.coordinate {
                Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 700, longitudinalMeters: 700)), interactionModes: []) {
                    Marker(store.name ?? "", monogram: Text(String((store.name ?? "").prefix(1))), coordinate: coordinate)
                        .tint(store.color)
                }
                .frame(height: 140)
            }
            HStack(spacing: 14) {
                StoreBadge(store: store, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name ?? "")
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                    Text("\(Image(systemName: store.travel.symbolName)) \(store.journey)")
                        .foregroundStyle(Color.inkSecondary)
                    if store.distanceKm > 0 {
                        Text(Measurement(value: store.distanceKm, unit: UnitLength.kilometers), format: .measurement(width: .abbreviated, usage: .road))
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }
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
