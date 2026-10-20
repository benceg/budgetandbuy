import CoreData
import SwiftUI

/// What the price sheet is pricing. `isPrompt` is true when it opened by
/// itself after ticking off an item, so dismissing it means "skip".
struct PricingTarget: Identifiable {
    let product: Product
    let store: Store
    var isPrompt = false

    var id: NSManagedObjectID { product.objectID }
}

/// A large price field over the number pad, pre-filled with the last price.
struct PriceSheet: View {
    let target: PricingTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var text: String
    @FocusState private var isFocused: Bool
    private let latest: Price?

    init(target: PricingTarget) {
        self.target = target
        latest = target.product.latestPrice(at: target.store)
        _text = State(initialValue: latest.map { Money.editableText($0.amountMinor) } ?? "")
    }

    private var amount: Int64? { Money.minorUnits(from: text) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    StoreBadge(store: target.store, size: 24)
                    Text(target.isPrompt
                         ? "What did it cost at \(target.store.name ?? "")?"
                         : "Price at \(target.store.name ?? "")")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                }
                AmountField(text: $text, isFocused: $isFocused)

                if let size = target.product.size {
                    Text(amount.map { "\(size.formatted) · \(size.unitPrice(of: $0))" } ?? size.formatted)
                        .font(.headline)
                        .foregroundStyle(Color.inkSecondary)
                        .monospacedDigit()
                }

                if let latest, let seen = latest.createdAt {
                    Text("Last seen at \(Money.format(latest.amountMinor)), \(Text(seen, format: .relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                } else if target.isPrompt {
                    Text("It’s remembered for next time, so you can compare shops. Shared with your household only.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
            .canvasBackground()
            .navigationTitle(target.product.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(target.isPrompt ? "Skip" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(amount == nil)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let amount else { return }
        target.store.recordPrice(amount, for: target.product)
        context.saveIfNeeded()
        dismiss()
    }
}
