import CoreData
import MapKit
import SwiftUI

/// The first launch: what the app does, the shops you use, how prices work,
/// and your first list. Every step but the last can be skipped.
struct OnboardingView: View {
    static let completedKey = "hasCompletedOnboarding"

    let household: Household

    private enum Step: Int, CaseIterable {
        case welcome, shops, prices, list
    }

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .welcome

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step != .welcome {
                    Button {
                        go(to: Step(rawValue: step.rawValue - 1) ?? .welcome)
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                            .font(.headline)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.ink)
                }
                Spacer()
                ProgressDots(count: Step.allCases.count, current: step.rawValue)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal)

            Group {
                switch step {
                case .welcome: WelcomeStep { go(to: .shops) }
                case .shops: ShopsStep(household: household) { go(to: .prices) }
                case .prices: PricesStep { go(to: .list) }
                case .list: FirstListStep(household: household) { dismiss() }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.canvas.ignoresSafeArea())
        .interactiveDismissDisabled()
        #if DEBUG
        .onAppear {
            if let debugStep = Step(rawValue: DebugLaunch.onboardingStep) { step = debugStep }
        }
        #endif
    }

    private func go(to next: Step) {
        withAnimation(.snappy) { step = next }
    }
}

private struct ProgressDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.brand : Color.brandSoft.opacity(0.4))
                    .frame(width: index == current ? 20 : 7, height: 7)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

/// A step's scrolling content with its buttons pinned to the bottom.
private struct StepLayout<Content: View, Buttons: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let buttons: Buttons

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 10) { buttons }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }
}

private struct StepTitle: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.title3)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: Welcome

private struct WelcomeStep: View {
    let next: () -> Void

    var body: some View {
        StepLayout {
            Image(AppTheme.current.logoName)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)
                .padding(.top, 20)
            StepTitle(title: "Shop smarter, together.", message: "A shared shopping list that learns what things cost at your shops.")
            VStack(alignment: .leading, spacing: 20) {
                Feature(systemImage: "person.2", title: "One list for the household", message: "Everyone adds to it, and sees what’s already in the basket.")
                Feature(systemImage: "sterlingsign", title: "Know where it’s cheapest", message: "Prices you see as you shop build up, so you can tell when a longer trip is worth it.")
                Feature(systemImage: "leaf", title: "Greener choices", message: "See the carbon you save by shopping closer to home.")
            }
            Text("No accounts, no adverts. Your lists and prices stay in your iCloud.")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        } buttons: {
            Button("Get Started", action: next)
                .buttonStyle(.primary)
        }
    }
}

private struct Feature: View {
    let systemImage: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.brandInk)
                .frame(width: 44, height: 44)
                .background(Color.brandPale, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Shops

private struct ShopsStep: View {
    @ObservedObject var household: Household
    let next: () -> Void

    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var stores: FetchedResults<Store>
    @State private var finder = ShopFinder()
    @State private var query = ""
    @State private var adding: Set<MKMapItem> = []
    @State private var namingShop: ShopChoice?

    init(household: Household, next: @escaping () -> Void) {
        self.household = household
        self.next = next
        _stores = FetchRequest(sortDescriptors: Store.oldestFirst, predicate: NSPredicate(format: "household == %@", household), animation: .default)
    }

    private var places: [MKMapItem] { query.isEmpty ? Array(finder.nearby.prefix(8)) : Array(finder.results.prefix(8)) }

    var body: some View {
        StepLayout {
            StepTitle(title: "Where do you shop?", message: "Add the shops you choose between, near and far. You can add more any time.")

            if !stores.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(stores, id: \.objectID) { store in
                        HStack(spacing: 6) {
                            StoreBadge(store: store, size: 24)
                            Text(store.name ?? "")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.ink)
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 12)
                        .padding(.vertical, 4)
                        .background(Color.surface, in: .capsule)
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.inkSecondary)
                TextField("Search shops and supermarkets", text: $query)
                    .submitLabel(.search)
            }
            .padding(14)
            .background(Color.surface, in: .capsule)

            VStack(spacing: 0) {
                if places.isEmpty {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                ForEach(places, id: \.self) { place in
                    PlaceAddRow(
                        place: place,
                        distance: finder.distance(to: place),
                        isAdded: isAdded(place),
                        isAdding: adding.contains(place)
                    ) {
                        Task { await quickAdd(place) }
                    }
                    if place != places.last {
                        Divider().overlay(Color.hairline)
                    }
                }
                if !query.isEmpty {
                    Divider().overlay(Color.hairline)
                    Button {
                        namingShop = ShopChoice(name: query)
                    } label: {
                        Label("Add “\(query)” by name", systemImage: "plus.circle")
                            .foregroundStyle(Color.brandInk)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        } buttons: {
            if stores.isEmpty {
                Button("Skip for Now", action: next)
                    .buttonStyle(.secondary)
            } else {
                Button("Continue", action: next)
                    .buttonStyle(.primary)
            }
        }
        .task { await finder.start() }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await finder.search(query)
        }
        .sheet(item: $namingShop) { choice in
            NavigationStack {
                ShopSetupView(household: household, choice: choice, finder: finder) { _ in
                    namingShop = nil
                    query = ""
                }
            }
        }
    }

    private var placeholder: LocalizedStringResource {
        switch finder.access {
        case .denied: "Location is off, so search for your shops by name."
        case .unknown: "Finding shops near you…"
        case .allowed: query.isEmpty ? "Looking for shops nearby…" : "No matching shops nearby."
        }
    }

    private func isAdded(_ place: MKMapItem) -> Bool {
        stores.contains { store in
            guard let coordinate = store.coordinate else { return false }
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: place.location) < 30
        }
    }

    /// Adds a shop in one tap, with the likely way of getting there.
    private func quickAdd(_ place: MKMapItem) async {
        guard !isAdded(place), !adding.contains(place) else { return }
        adding.insert(place)
        defer { adding.remove(place) }
        let mode = finder.likelyMode(to: place)
        let journey = await finder.journey(to: place, by: mode)
        let used = Set(stores.compactMap(\.colorName))
        let store = household.addStore()
        store.name = ShopSetupView.shortName(place.name ?? "")
        store.colorName = ListAppearance.colorNames.first { !used.contains($0) } ?? "slate"
        store.travel = mode
        store.travelMinutes = Int16(journey?.minutes ?? 10)
        store.distanceKm = journey?.kilometres ?? 0
        store.coordinate = place.location.coordinate
        context.saveIfNeeded()
    }
}

extension ShopChoice: Identifiable {
    var id: Self { self }
}

private struct PlaceAddRow: View {
    let place: MKMapItem
    let distance: CLLocationDistance?
    let isAdded: Bool
    let isAdding: Bool
    let add: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name ?? "")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.ink)
                Text([place.shortAddress, distance.map { Measurement(value: $0, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)) }]
                    .compactMap(\.self).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if isAdding {
                ProgressView()
            } else if isAdded {
                Label("Added", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandInk)
            } else {
                Button("Add", action: add)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.onBrand)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.brand, in: .capsule)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: Prices

private struct PricesStep: View {
    let next: () -> Void

    var body: some View {
        StepLayout {
            StepTitle(title: "Prices come from you", message: "There’s no price database. You build your own as you shop, shared only with your household.")
            PriceExample()
            HowItWorksSteps()
        } buttons: {
            Button("Continue", action: next)
                .buttonStyle(.primary)
        }
    }
}

/// A picture of what the app learns: one item, priced at two shops.
struct PriceExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(GroceryIcon(stringLiteral: "milk").imageName)
                    .font(.title)
                    .foregroundStyle(Color.ink)
                    .frame(width: 52, height: 52)
                    .background(Color.brandPale, in: .circle)
                VStack(alignment: .leading) {
                    Text("Semi-skimmed milk")
                        .font(.headline)
                    Text("4 pints")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
                .foregroundStyle(Color.ink)
            }
            example(shop: "Aldi", colorName: "slate", price: 145, journey: String(localized: "20 min drive"), isCheapest: true)
            example(shop: "Corner shop", colorName: "apricot", price: 189, journey: String(localized: "4 min walk"), isCheapest: false)
        }
        .card(padding: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("For example, milk costs £1.45 at Aldi, a 20 minute drive, and £1.89 at the corner shop, a 4 minute walk.")
    }

    private func example(shop: String, colorName: String, price: Int64, journey: String, isCheapest: Bool) -> some View {
        HStack(spacing: 12) {
            StoreBadge(name: shop, colorName: colorName, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(shop).font(.subheadline.weight(.semibold))
                Text(journey).font(.caption).foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            if isCheapest {
                Tag(text: String(localized: "Cheapest"), foreground: .brandInk, background: .brandPale)
            }
            Text(Money.format(price))
                .font(.headline)
                .monospacedDigit()
        }
        .foregroundStyle(Color.ink)
    }
}

/// The three things to do, in order.
struct HowItWorksSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            step(1, "Make your list", "Add what you need. Everyone in the household can add to it.")
            step(2, "Tap Start Shopping in the shop", "Tick things off as they go in your basket. The first time you buy something there, type in the price.")
            step(3, "See where it’s cheapest", "Next time, Where to Shop shows what your list costs at each shop, and whether a longer trip is worth it.")
        }
    }

    private func step(_ number: Int, _ title: LocalizedStringResource, _ message: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number, format: .number)
                .font(.headline)
                .foregroundStyle(Color.onBrand)
                .frame(width: 32, height: 32)
                .background(Color.brand, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The prices explanation again, from the Household tab.
struct HowItWorksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Budget & Buy learns what things cost at your shops from the prices you see as you shop. Nobody else sees them except your household.")
                        .font(.body)
                        .foregroundStyle(Color.inkSecondary)
                    PriceExample()
                    HowItWorksSteps()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sizes matter")
                            .font(.headline)
                        Text("“Milk 2L” and “Milk 4 pints” are kept apart, each with its own prices, so comparisons are like for like. Type the size with the name.")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .foregroundStyle(Color.ink)
                }
                .padding(24)
            }
            .canvasBackground()
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: First list

private struct FirstListStep: View {
    @ObservedObject var household: Household
    let finish: () -> Void

    @Environment(\.managedObjectContext) private var context
    @State private var name = String(localized: "Weekly Shop")
    @State private var picked: Set<String> = []

    private static let starters = ["Milk", "Bread", "Eggs", "Bananas", "Apples", "Cheese", "Butter", "Pasta", "Rice", "Tea", "Coffee", "Toilet roll", "Washing-up liquid", "Chicken", "Tomatoes", "Yoghurt"]

    private var hasLists: Bool { !(household.lists?.isEmpty ?? true) }

    var body: some View {
        StepLayout {
            if hasLists {
                StepTitle(title: "You’re all set", message: "Your lists are waiting. Tap Start Shopping when you get to a shop.")
            } else {
                StepTitle(title: "Start your first list", message: "Give it a name, and pick a few things to get going.")
                TextField("List name", text: $name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .padding(16)
                    .background(Color.surface, in: .rect(cornerRadius: 16))
                FlowLayout(spacing: 8) {
                    ForEach(Self.starters, id: \.self) { starter in
                        let isPicked = picked.contains(starter)
                        Button {
                            if isPicked { picked.remove(starter) } else { picked.insert(starter) }
                        } label: {
                            HStack(spacing: 6) {
                                if let icon = GroceryCatalogue.entry(for: starter)?.icon {
                                    Image(icon.imageName)
                                }
                                Text(starter)
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isPicked ? Color.onBrand : Color.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isPicked ? Color.brand : Color.surface, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isPicked ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: picked)
            }
        } buttons: {
            Button(hasLists ? "Start Using Budget & Buy" : "Create List", action: create)
                .buttonStyle(.primary)
                .disabled(!hasLists && ProductName.display(name).isEmpty)
        }
    }

    private func create() {
        if !hasLists {
            let list = household.addList()
            list.name = ProductName.display(name)
            for starter in Self.starters where picked.contains(starter) {
                list.addItem(named: starter)
            }
            context.saveIfNeeded()
        }
        finish()
    }
}
