import CoreData
import SwiftUI

/// How the month's spending is going against the budget, and what shopping
/// where you did saved, or cost extra, against your other shops' prices.
struct SavingsScreen: View {
    static let basisKey = "savingsBasis"

    @ObservedObject var household: Household
    let households: [Household]
    @Binding var selectedHouseholdID: String
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var trips: FetchedResults<Trip>
    @State private var period: TripStats.Period = .month
    // A way of looking, so it's kept on this iPhone rather than shared.
    @AppStorage(Self.basisKey) private var basis: Savings.Basis = .average
    @State private var isEditingBudget = false

    init(household: Household, households: [Household], selectedHouseholdID: Binding<String>) {
        self.household = household
        self.households = households
        _selectedHouseholdID = selectedHouseholdID
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
                    budget
                    if trips.isEmpty {
                        EmptyState(
                            systemImage: "banknote",
                            title: "Your savings start here",
                            message: "Each time you finish shopping, Budget & Buy compares what you paid with your other shops’ prices for the same things. What you save, and what convenience costs you, adds up here."
                        )
                        .card()
                    } else {
                        let stats = TripStats(trips: trips, period: period)
                        ChipPicker(options: TripStats.Period.allCases.map { ($0, $0.title) }, selection: $period)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compare with your other shops’ prices")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkSecondary)
                            ChipPicker(options: Savings.Basis.allCases.map { ($0, $0.title) }, selection: $basis)
                        }
                        hero(stats)
                        tiles(stats)
                        if !stats.stores.isEmpty { shops(stats) }
                        recent(stats)
                        Text("Each trip is compared with the latest prices at your other shops when it finished. Things with no price at another shop aren’t counted.")
                            .font(.footnote)
                            .foregroundStyle(Color.inkSecondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding()
            }
            .canvasBackground()
            .navigationTitle("Savings")
            .householdSwitcher(household, households: households, selection: $selectedHouseholdID)
            .sheet(isPresented: $isEditingBudget) {
                BudgetSheet(target: .month(household))
            }
        }
    }

    /// This month against the budget, whichever period is showing below.
    private var budget: some View {
        let spent = TripStats(trips: trips, period: .month).spentMinor
        let progress = BudgetProgress(spentMinor: spent, budgetMinor: household.monthlyBudgetMinor)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Spent in \(Date.now.formatted(.dateTime.month(.wide)))")
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
            HStack(alignment: .firstTextBaseline) {
                HeroAmount(minorUnits: spent)
                if household.monthlyBudgetMinor > 0 {
                    Text("of \(Money.format(household.monthlyBudgetMinor))")
                        .font(.headline)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            if household.monthlyBudgetMinor > 0 {
                ProgressBar(fraction: progress.fraction, color: progress.isOver ? .apricot : .brand)
                HStack {
                    Text(progress.isOver
                         ? String(localized: "\(Money.format(-progress.remainingMinor)) over budget")
                         : String(localized: "\(Money.format(progress.remainingMinor)) under budget"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(progress.isOver ? Color.apricot : Color.brandInk)
                    Spacer()
                    Button("Change") { isEditingBudget = true }
                        .font(.subheadline)
                }
            } else {
                Button("Set a Monthly Budget") { isEditingBudget = true }
                    .buttonStyle(.secondary)
            }
        }
        .card(padding: 18)
    }

    private func hero(_ stats: TripStats) -> some View {
        let amount = stats.savings[basis]
        return VStack(alignment: .leading, spacing: 4) {
            Text(basis.headline(for: amount))
                .font(.subheadline)
                .foregroundStyle(Color.onBrand.opacity(0.8))
            Text(Money.format(abs(amount)))
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Color.onBrand)
            Text(basis.detail(count: stats.savings.comparedCount))
                .font(.subheadline)
                .foregroundStyle(Color.onBrand.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand, in: .rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func tiles(_ stats: TripStats) -> some View {
        HStack(spacing: 12) {
            SummaryTile(title: "Spent", value: Money.format(stats.spentMinor), systemImage: "basket")
            SummaryTile(title: stats.trips.count == 1 ? "Trip" : "Trips", value: stats.trips.count.formatted(), systemImage: "storefront")
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
                            SavingText(savings: summary.savings, basis: basis)
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
                    TripRow(trip: trip, basis: basis, colorName: colorName(of: trip.storeName ?? ""))
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

extension Savings.Basis {
    /// What an amount saved, or paid extra, is called.
    func headline(for amountMinor: Int64) -> String {
        switch (self, amountMinor.signum()) {
        case (.cheapest, -1): String(localized: "Paid extra for convenience")
        case (.dearest, 1): String(localized: "Saved by shopping cheaper")
        case (_, 1): String(localized: "Saved by shopping around")
        case (_, -1): String(localized: "Paid extra")
        default: String(localized: "No difference")
        }
    }

    /// "vs cheapest", in the trip summary.
    var comparisonTitle: LocalizedStringResource {
        switch self {
        case .cheapest: "vs cheapest"
        case .average: "vs average"
        case .dearest: "vs dearest"
        }
    }

    /// What it was compared with.
    func detail(count: Int) -> String {
        let things = count == 1 ? String(localized: "1 thing") : String(localized: "\(count) things")
        return switch self {
        case .cheapest: String(localized: "Compared with your other shops’ cheapest prices, on \(things).")
        case .average: String(localized: "Compared with your other shops’ average prices, on \(things).")
        case .dearest: String(localized: "Compared with your other shops’ dearest prices, on \(things).")
        }
    }
}

/// "saved £1.20" or "£0.40 extra", or nothing when there was nothing to compare.
private struct SavingText: View {
    let savings: Savings
    let basis: Savings.Basis

    var body: some View {
        let amount = savings[basis]
        if savings.comparedCount > 0, amount != 0 {
            Text(amount > 0 ? "saved \(Money.format(amount))" : "\(Money.format(-amount)) extra")
                .font(.caption.weight(.semibold))
                .foregroundStyle(amount > 0 ? Color.leaf : Color.apricot)
        }
    }
}

private struct TripRow: View {
    @ObservedObject var trip: Trip
    let basis: Savings.Basis
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
                SavingText(savings: trip.savings, basis: basis)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
