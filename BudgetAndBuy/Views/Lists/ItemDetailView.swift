import CoreData
import SwiftUI

/// One thing on a list: how many, and what it costs at each of your shops.
struct ItemDetailView: View {
    @ObservedObject var item: Item
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var stores: FetchedResults<Store>
    // Fetched so the prices refresh as soon as one is saved.
    @FetchRequest private var prices: FetchedResults<Price>
    @State private var isEditing = false
    @State private var pricing: PricingTarget?

    init(item: Item) {
        self.item = item
        let household = item.list?.household
        _stores = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))],
            predicate: household.map { NSPredicate(format: "household == %@", $0) } ?? NSPredicate(value: false)
        )
        _prices = FetchRequest(
            sortDescriptors: [],
            predicate: item.product.map { NSPredicate(format: "product == %@", $0) } ?? NSPredicate(value: false)
        )
    }

    private var product: Product? { item.product }

    private var cheapest: Store? {
        guard let product else { return nil }
        let priced = stores.compactMap { store in product.latestPrice(at: store).map { (store, $0.amountMinor) } }
        guard priced.count > 1 else { return nil }
        return priced.min { $0.1 < $1.1 }?.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                quantity
                pricesCard
                Button("Remove from List", role: .destructive, action: remove)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.apricot)
                    .padding(.top, 8)
            }
            .padding()
        }
        .canvasBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ItemEditor(item: item)
        }
        .sheet(item: $pricing) { target in
            PriceSheet(target: target)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ProductIcon(product: product)
                .font(.system(size: 52))
                .foregroundStyle(Color.ink)
                .frame(width: 112, height: 112)
                .background(Color.brandPale, in: .circle)
            Text(product?.name ?? "")
                .font(.title.bold())
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                if let size = product?.size {
                    Tag(text: size.formatted)
                }
                if let category = product?.category {
                    Tag(text: String(localized: category.title), foreground: .brandInk, background: .brandPale)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var quantity: some View {
        HStack {
            Text("Quantity")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Spacer()
            HStack(spacing: 4) {
                stepButton("minus", label: "Fewer", delta: -1)
                    .disabled(item.quantity <= 1)
                Text(item.quantity, format: .number)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 40)
                    .foregroundStyle(Color.ink)
                stepButton("plus", label: "More", delta: 1)
            }
        }
        .card()
        .accessibilityElement(children: .contain)
    }

    private func stepButton(_ symbol: String, label: LocalizedStringResource, delta: Int16) -> some View {
        Button {
            withAnimation { item.quantity = max(1, item.quantity + delta) }
            context.saveIfNeeded()
        } label: {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Color.brandInk)
                .frame(width: 44, height: 44)
                .background(Color.brandPale, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var pricesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Prices")
            if stores.isEmpty {
                Text("Add the shops you use from the Shops tab, then prices you see appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
            ForEach(stores, id: \.objectID) { store in
                Button {
                    if let product { pricing = PricingTarget(product: product, store: store) }
                } label: {
                    PriceRow(store: store, price: product?.latestPrice(at: store), size: product?.size, isCheapest: store == cheapest, quantity: item.quantity)
                }
                .buttonStyle(.plain)
                if store != stores.last {
                    Divider().overlay(Color.hairline)
                }
            }
            if !stores.isEmpty {
                Text("Prices are saved when you tick this off while shopping, or tap a shop to add one.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .card()
    }

    private func remove() {
        dismiss()
        context.delete(item)
        context.saveIfNeeded()
    }
}

private struct PriceRow: View {
    let store: Store
    let price: Price?
    let size: ProductSize?
    let isCheapest: Bool
    let quantity: Int16

    var body: some View {
        HStack(spacing: 12) {
            StoreBadge(store: store, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(store.name ?? "")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.ink)
                    if isCheapest {
                        Tag(text: String(localized: "Cheapest"), foreground: .brandInk, background: .brandPale)
                    }
                }
                if let seen = price?.createdAt {
                    Text("Seen \(Text(seen, format: .relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer()
            if let price {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.format(price.amountMinor))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                    if let size {
                        Text(size.unitPrice(of: price.amountMinor))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                    } else if quantity > 1 {
                        Text("\(Money.format(price.amountMinor * Int64(quantity))) for \(quantity)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            } else {
                Text("Add Price")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandInk)
            }
        }
        .contentShape(.rect)
    }
}
