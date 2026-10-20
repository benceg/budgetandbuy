import CoreData
import SwiftUI

enum CarbonFormat {
    static func format(_ kg: Double) -> String {
        Measurement(value: kg, unit: UnitMass.kilograms).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1)))
        )
    }
}

/// A Reminders-style summary tile: icon and value on top, title beneath.
struct StatTile: View {
    let title: LocalizedStringResource
    let value: String
    let symbolName: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ListIcon(symbolName: symbolName, color: color, size: 34)
                Spacer()
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

/// What the household has spent and saved, and the trips behind it.
struct StatsView: View {
    @ObservedObject var household: Household
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var trips: FetchedResults<Trip>
    @State private var period: TripStats.Period = .year

    init(household: Household) {
        self.household = household
        _trips = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: NSPredicate(format: "household == %@", household),
            animation: .default
        )
    }

    var body: some View {
        let stats = TripStats(trips: trips, period: period)
        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(TripStats.Period.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        StatTile(title: "Saved", value: Money.format(stats.savedMinor), symbolName: "banknote.fill", color: .green)
                        StatTile(title: "CO₂ Avoided", value: CarbonFormat.format(stats.carbonAvoidedKg), symbolName: "leaf.fill", color: .mint)
                    }
                    GridRow {
                        StatTile(title: "Spent", value: Money.format(stats.spentMinor), symbolName: "basket.fill", color: .blue)
                        StatTile(title: "Trips", value: stats.trips.count.formatted(), symbolName: "signpost.right.fill", color: .orange)
                    }
                }
            } footer: {
                Text("Each trip is compared with your nearest store, or, if you shopped there, with the store that would have been cheapest. Carbon is estimated from the distances you’ve entered.")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if !stats.stores.isEmpty {
                Section("Stores") {
                    ForEach(stats.stores) { store in
                        LabeledContent {
                            VStack(alignment: .trailing) {
                                Text(Money.format(store.spentMinor))
                                    .monospacedDigit()
                                if store.savedMinor > 0 {
                                    Text("saved \(Money.format(store.savedMinor))")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        } label: {
                            Text(store.name)
                            Text(store.tripCount == 1 ? "1 trip" : "\(store.tripCount) trips")
                        }
                    }
                }
            }

            Section("Trips") {
                if stats.trips.isEmpty {
                    Text("Finish shopping from a list to record a trip.")
                        .foregroundStyle(.secondary)
                }
                ForEach(stats.trips, id: \.objectID) { trip in
                    TripRow(trip: trip)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(trip)
                                context.saveIfNeeded()
                            }
                        }
                }
            }
        }
        .navigationTitle("Savings")
    }
}

private struct TripRow: View {
    @ObservedObject var trip: Trip

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing) {
                Text(Money.format(trip.spentMinor))
                    .monospacedDigit()
                if trip.savedMinor > 0 {
                    Text("saved \(Money.format(trip.savedMinor))")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if trip.carbonSavedKg >= 0.05 {
                    Text("\(CarbonFormat.format(trip.carbonSavedKg)) CO₂ avoided")
                        .font(.caption)
                        .foregroundStyle(.mint)
                }
            }
        } label: {
            Text("\(Image(systemName: trip.travel.symbolName)) \(trip.storeName ?? "")")
            if let date = trip.createdAt {
                Text("\(date, format: .dateTime.day().month().year()) · \(trip.listName ?? "")")
            }
        }
    }
}
