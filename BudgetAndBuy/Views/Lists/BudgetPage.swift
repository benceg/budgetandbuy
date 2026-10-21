import CoreData
import SwiftUI

/// What the list is likely to cost against its budget, by aisle, and how the
/// household's month is going.
struct BudgetPage: View {
    @ObservedObject var list: ShoppingList
    let items: [Item]
    let stores: [Store]
    let shoppingStore: Store?

    private enum Scope: Hashable { case list, month }
    @State private var scope: Scope = .list
    @State private var editing: BudgetTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ChipPicker(options: [(Scope.list, "This List"), (Scope.month, "This Month")], selection: $scope)
                switch scope {
                case .list: listBudget
                case .month:
                    if let household = list.household {
                        MonthBudget(household: household) { editing = .month(household) }
                    }
                }
            }
            .padding()
        }
        .canvasBackground()
        .sheet(item: $editing) { target in
            BudgetSheet(target: target)
        }
    }

    @ViewBuilder
    private var listBudget: some View {
        let estimate = ListEstimate(items: items, stores: stores, preferring: shoppingStore)
        let progress = BudgetProgress(spentMinor: estimate.totalMinor, budgetMinor: list.budgetMinor)

        VStack(alignment: .leading, spacing: 14) {
            Text("Estimated cost")
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
            HStack(alignment: .firstTextBaseline) {
                HeroAmount(minorUnits: estimate.totalMinor)
                if list.budgetMinor > 0 {
                    Text("of \(Money.format(list.budgetMinor))")
                        .font(.headline)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            if list.budgetMinor > 0 {
                ProgressBar(fraction: progress.fraction, color: progress.isOver ? .apricot : .brand)
                Text(progress.isOver
                     ? String(localized: "\(Money.format(-progress.remainingMinor)) over budget")
                     : String(localized: "\(Money.format(progress.remainingMinor)) to spare"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.isOver ? Color.apricot : Color.brandInk)
            }
            Text(basis(estimate))
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(list.budgetMinor > 0 ? "Change Budget" : "Set a Budget") { editing = .list(list) }
                .buttonStyle(.secondary)
        }
        .card(padding: 18)

        if !estimate.aisles.isEmpty {
            SectionHeading(title: "By aisle")
                .padding(.top, 4)
            AisleBreakdown(aisles: estimate.aisles)
        }
    }

    private func basis(_ estimate: ListEstimate) -> String {
        let source = shoppingStore.map { String(localized: "Uses prices at \($0.name ?? ""), or the lowest seen elsewhere.") }
            ?? String(localized: "Uses the lowest price you’ve seen for each item at your shops.")
        let missing = estimate.itemCount - estimate.pricedCount
        guard missing > 0 else { return source }
        let unpriced = missing == 1
            ? String(localized: "1 item has no price yet, so isn’t included.")
            : String(localized: "\(missing) items have no price yet, so aren’t included.")
        return "\(source) \(unpriced)"
    }
}

private struct AisleBreakdown: View {
    let aisles: [ListEstimate.Aisle]

    var body: some View {
        let largest = aisles.map(\.totalMinor).max() ?? 1
        VStack(spacing: 16) {
            ForEach(aisles) { aisle in
                HStack(spacing: 12) {
                    Image(systemName: aisle.category.symbolName)
                        .font(.subheadline)
                        .foregroundStyle(Color.brandInk)
                        .frame(width: 36, height: 36)
                        .background(Color.brandPale, in: .circle)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(aisle.category.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Text(Money.format(aisle.totalMinor))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.ink)
                        }
                        ProgressBar(fraction: Double(aisle.totalMinor) / Double(max(1, largest)), color: .brandSoft, height: 6)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}

/// The household's spending this month, from the shops it has finished.
private struct MonthBudget: View {
    @ObservedObject var household: Household
    let onEdit: () -> Void
    @FetchRequest private var trips: FetchedResults<Trip>

    init(household: Household, onEdit: @escaping () -> Void) {
        self.household = household
        self.onEdit = onEdit
        _trips = FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "household == %@", household))
    }

    var body: some View {
        let stats = TripStats(trips: trips, period: .month)
        let progress = BudgetProgress(spentMinor: stats.spentMinor, budgetMinor: household.monthlyBudgetMinor)
        VStack(alignment: .leading, spacing: 14) {
            Text("Spent in \(Date.now.formatted(.dateTime.month(.wide)))")
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
            HStack(alignment: .firstTextBaseline) {
                HeroAmount(minorUnits: stats.spentMinor)
                if household.monthlyBudgetMinor > 0 {
                    Text("of \(Money.format(household.monthlyBudgetMinor))")
                        .font(.headline)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            if household.monthlyBudgetMinor > 0 {
                ProgressBar(fraction: progress.fraction, color: progress.isOver ? .apricot : .brand)
                Text(progress.isOver
                     ? String(localized: "\(Money.format(-progress.remainingMinor)) over budget")
                     : String(localized: "\(Money.format(progress.remainingMinor)) left this month"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.isOver ? Color.apricot : Color.brandInk)
            }
            Text("Counts every trip the household has finished this month, across all its lists.")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
            Button(household.monthlyBudgetMinor > 0 ? "Change Monthly Budget" : "Set a Monthly Budget", action: onEdit)
                .buttonStyle(.secondary)
        }
        .card(padding: 18)

        if !stats.stores.isEmpty {
            SectionHeading(title: "By shop")
                .padding(.top, 4)
            VStack(spacing: 14) {
                ForEach(stats.stores) { store in
                    HStack(spacing: 12) {
                        StoreBadge(name: store.name, colorName: household.stores?.first { $0.name == store.name }?.colorName, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.name)
                                .font(.subheadline.weight(.medium))
                            Text(store.tripCount == 1 ? "1 trip" : "\(store.tripCount) trips")
                                .font(.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Spacer()
                        Text(Money.format(store.spentMinor))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.ink)
                }
            }
            .card()
        }
    }
}

enum BudgetTarget: Identifiable {
    case list(ShoppingList)
    case month(Household)

    var id: NSManagedObjectID {
        switch self {
        case .list(let list): list.objectID
        case .month(let household): household.objectID
        }
    }
}

/// A large amount field for setting a budget.
struct BudgetSheet: View {
    let target: BudgetTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(target: BudgetTarget) {
        self.target = target
        let current: Int64 = switch target {
        case .list(let list): list.budgetMinor
        case .month(let household): household.monthlyBudgetMinor
        }
        _text = State(initialValue: current > 0 ? Money.editableText(current) : "")
    }

    private var amount: Int64? { Money.minorUnits(from: text) }

    private var title: LocalizedStringResource {
        switch target {
        case .list: "Budget for This List"
        case .month: "Monthly Budget"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                AmountField(text: $text, isFocused: $isFocused)
                Text(target.isMonthly
                     ? "Every trip you finish counts towards it. Everyone in the household shares it."
                     : "See how the list’s estimated cost compares as you add things.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
            .canvasBackground()
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(amount ?? 0) }
                        .disabled(amount == nil && !text.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Remove Budget", role: .destructive) { save(0) }
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func save(_ minor: Int64) {
        switch target {
        case .list(let list): list.budgetMinor = minor
        case .month(let household): household.monthlyBudgetMinor = minor
        }
        context.saveIfNeeded()
        dismiss()
    }
}

private extension BudgetTarget {
    var isMonthly: Bool {
        if case .month = self { return true }
        return false
    }
}

/// A large currency field over the number pad.
struct AmountField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Money.currencySymbol)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkSecondary)
            TextField("0.00", text: $text)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .keyboardType(.decimalPad)
                .focused(isFocused)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}
