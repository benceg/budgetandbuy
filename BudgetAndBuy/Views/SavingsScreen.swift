import CoreData
import SwiftUI

enum CarbonFormat {
    static func format(_ kg: Double) -> String {
        Measurement(value: kg, unit: UnitMass.kilograms).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1)))
        )
    }
}

/// What choosing where to shop has saved, in money and in carbon, and the
/// shops behind it.
struct SavingsScreen: View {
    @ObservedObject var household: Household
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var trips: FetchedResults<Trip>
    @State private var period: TripStats.Period = .month

    init(household: Household) {
        self.household = household
        _trips = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: NSPredicate(format: "household == %@", household),
            animation: .default
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if trips.isEmpty {
                        EmptyState(
                            systemImage: "leaf",
                            title: "Your savings start here",
                            message: "Each time you finish shopping, Budget & Buy compares it with your nearest shop, or, if you shopped nearby, with the cheapest. Money saved and carbon avoided add up here."
                        )
                        .card()
                    } else {
                        let stats = TripStats(trips: trips, period: period)
                        ChipPicker(options: TripStats.Period.allCases.map { ($0, $0.title) }, selection: $period)
                        hero(stats)
                        tiles(stats)
                        if !stats.stores.isEmpty { shops(stats) }
                        recent(stats)
                        Text("Savings count the items priced at both shops being compared. Carbon is estimated for a round trip from the distances of your shops: about 0.17 kg CO₂e per km by car and 0.1 by bus.")
                            .font(.footnote)
                            .foregroundStyle(Color.inkSecondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding()
            }
            .canvasBackground()
            .navigationTitle("Savings")
        }
    }

    private func hero(_ stats: TripStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved by shopping around")
                    .font(.subheadline)
                    .foregroundStyle(Color.onForest.opacity(0.8))
                Text(Money.format(stats.savedMinor))
                    .font(.system(size: 44, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Color.onForest)
            }
            Divider().overlay(Color.onForest.opacity(0.25))
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.title3)
                    .foregroundStyle(Color.forest)
                    .frame(width: 40, height: 40)
                    .background(Color.sagePale, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(CarbonFormat.format(stats.carbonAvoidedKg)) CO₂e avoided")
                        .font(.headline)
                        .foregroundStyle(Color.onForest)
                    Text(carbonDetail(stats.carbonAvoidedKg))
                        .font(.subheadline)
                        .foregroundStyle(Color.onForest.opacity(0.8))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.forest, in: .rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func carbonDetail(_ kg: Double) -> String {
        let kilometres = kg / TravelMode.drive.carbonKgPerKm
        guard kilometres >= 1 else { return String(localized: "by shopping closer to home") }
        let distance = Measurement(value: kilometres, unit: UnitLength.kilometers)
            .formatted(.measurement(width: .wide, usage: .road, numberFormatStyle: .number.precision(.fractionLength(0))))
        return String(localized: "About \(distance) less driving, by shopping closer to home")
    }

    private func tiles(_ stats: TripStats) -> some View {
        HStack(spacing: 12) {
            SummaryTile(title: "Spent", value: Money.format(stats.spentMinor), systemImage: "basket")
            SummaryTile(title: stats.trips.count == 1 ? "Trip" : "Trips", value: stats.trips.count.formatted(), systemImage: "car")
        }
    }

    private func shops(_ stats: TripStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "By shop")
            VStack(spacing: 14) {
                ForEach(stats.stores) { summary in
                    HStack(spacing: 12) {
                        StoreBadge(name: summary.name, colorName: colorName(of: summary.name), size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.name)
                                .font(.body.weight(.medium))
                            Text(summary.tripCount == 1 ? "1 trip" : "\(summary.tripCount) trips")
                                .font(.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Money.format(summary.spentMinor))
                                .monospacedDigit()
                            if summary.savedMinor > 0 {
                                Text("saved \(Money.format(summary.savedMinor))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.leaf)
                            }
                        }
                    }
                    .foregroundStyle(Color.ink)
                    .accessibilityElement(children: .combine)
                }
            }
            .card()
        }
    }

    private func recent(_ stats: TripStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Recent trips")
            VStack(spacing: 0) {
                ForEach(stats.trips.prefix(20), id: \.objectID) { trip in
                    TripRow(trip: trip, colorName: colorName(of: trip.storeName ?? ""))
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(trip)
                                context.saveIfNeeded()
                            }
                        }
                    if trip != stats.trips.prefix(20).last {
                        Divider().overlay(Color.hairline).padding(.leading, 50)
                    }
                }
                if stats.trips.isEmpty {
                    Text("No trips in this period.")
                        .foregroundStyle(Color.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()
        }
    }

    private func colorName(of storeName: String) -> String? {
        household.stores?.first { $0.name == storeName }?.colorName
    }
}

private struct TripRow: View {
    @ObservedObject var trip: Trip
    let colorName: String?

    var body: some View {
        HStack(spacing: 12) {
            StoreBadge(name: trip.storeName, colorName: colorName, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.storeName ?? "")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.ink)
                if let date = trip.createdAt {
                    Text("\(date, format: .dateTime.day().month()) · \(trip.listName ?? "")")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(trip.spentMinor))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                if trip.savedMinor > 0 {
                    Text("saved \(Money.format(trip.savedMinor))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.leaf)
                } else if trip.carbonSavedKg >= 0.05 {
                    Text("\(CarbonFormat.format(trip.carbonSavedKg)) CO₂e avoided")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.leaf)
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
