import CoreData
import SwiftUI

/// Shown after finishing a shop: what it cost and what choosing that shop saved.
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
                        if let compared = trip.comparedStoreName, trip.savedMinor != 0 {
                            figure(
                                title: trip.savedMinor > 0 ? "Saved" : "Paid extra",
                                value: Money.format(abs(trip.savedMinor)),
                                detail: String(localized: "Compared with \(compared)"),
                                systemImage: "sterlingsign",
                                tint: trip.savedMinor > 0 ? .leaf : .apricot
                            )
                        }
                    }
                    .card()

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
