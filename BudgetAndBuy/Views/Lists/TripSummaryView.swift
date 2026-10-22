import CoreData
import SwiftUI

/// Shown after finishing a shop: what it cost, and what it saved or cost
/// extra against your other shops' cheapest, average and dearest prices.
struct TripSummaryView: View {
    @ObservedObject var trip: Trip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color.onBrand)
                            .frame(width: 80, height: 80)
                            .background(Color.brand, in: .circle)
                            .symbolEffect(.bounce, options: .nonRepeating)
                            .accessibilityHidden(true)
                        Text("Shop done")
                            .font(.title.bold())
                            .foregroundStyle(Color.ink)
                        Text("\(trip.storeName ?? "") · \(trip.itemCount == 1 ? String(localized: "1 item") : String(localized: "\(trip.itemCount) items"))")
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 14) {
                        figure(
                            title: "Spent",
                            value: Money.format(trip.spentMinor),
                            detail: trip.pricedCount < trip.itemCount
                                ? String(localized: "For the \(trip.pricedCount) items with prices")
                                : nil,
                            systemImage: "basket",
                            tint: .brandInk
                        )
                    }
                    .card()

                    comparisons

                    Text("Prices you confirmed are saved for next time. Your savings add up in the Savings tab.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .canvasBackground()
            .safeAreaBar(edge: .bottom) {
                Button("Done") { dismiss() }
                    .buttonStyle(.primary)
                    .padding(.horizontal)
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var comparisons: some View {
        let savings = trip.savings
        if savings.comparedCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text(savings.comparedCount == 1
                     ? String(localized: "On the 1 thing with prices at your other shops")
                     : String(localized: "On the \(savings.comparedCount) things with prices at your other shops"))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                ForEach(Savings.Basis.allCases) { basis in
                    let amount = savings[basis]
                    HStack {
                        Text(basis.comparisonTitle)
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Text(amount > 0 ? String(localized: "Saved \(Money.format(amount))")
                             : amount < 0 ? String(localized: "Paid \(Money.format(-amount)) extra")
                             : String(localized: "Same"))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(amount > 0 ? Color.leaf : amount < 0 ? Color.apricot : Color.inkSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
            Text("Nothing in this shop has a price at your other shops yet, so there’s nothing to compare it with.")
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        }
    }

    private func figure(title: LocalizedStringResource, value: String, detail: String?, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Color.brandPale, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer()
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(tint == .apricot ? Color.apricot : Color.ink)
        }
        .accessibilityElement(children: .combine)
    }
}
