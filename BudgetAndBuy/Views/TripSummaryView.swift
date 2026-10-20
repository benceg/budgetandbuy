import CoreData
import SwiftUI

/// Shown after finishing a shop: what it cost and what it saved.
struct TripSummaryView: View {
    @ObservedObject var trip: Trip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                            .symbolEffect(.bounce, options: .nonRepeating)
                            .accessibilityHidden(true)
                        Text("Shopping Done")
                            .font(.title2.bold())
                        Text(trip.storeName ?? "")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)

                Section {
                    LabeledContent {
                        Text(Money.format(trip.spentMinor))
                            .monospacedDigit()
                    } label: {
                        Label("Spent", systemImage: "basket")
                        if trip.pricedCount < trip.itemCount {
                            Text("For the \(trip.pricedCount) of \(trip.itemCount) items with prices")
                        }
                    }

                    if let compared = trip.comparedStoreName {
                        if trip.savedMinor != 0 {
                            LabeledContent {
                                Text(Money.format(abs(trip.savedMinor)))
                                    .monospacedDigit()
                                    .foregroundStyle(trip.savedMinor > 0 ? .green : .secondary)
                            } label: {
                                Label(trip.savedMinor > 0 ? "Saved" : "Paid Extra", systemImage: "banknote")
                                Text("Compared with \(compared)")
                            }
                        }
                        if abs(trip.carbonSavedKg) >= 0.05 {
                            LabeledContent {
                                Text(CarbonFormat.format(abs(trip.carbonSavedKg)))
                                    .monospacedDigit()
                                    .foregroundStyle(trip.carbonSavedKg > 0 ? .mint : .secondary)
                            } label: {
                                Label(trip.carbonSavedKg > 0 ? "CO₂ Avoided" : "Extra CO₂", systemImage: "leaf")
                                Text("Compared with \(compared)")
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
