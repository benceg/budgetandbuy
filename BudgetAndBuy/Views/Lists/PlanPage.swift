import CoreData
import MapKit
import SwiftUI

/// Where to buy the list: the cheapest way, the one-stop way and the closest
/// way, with what each costs, and the route between the shops from where you are.
struct PlanPage: View {
    @ObservedObject var list: ShoppingList
    let items: [Item]
    let stores: [Store]
    let onStartShopping: (Store) -> Void

    @State private var goal: ShoppingPlan.Goal = .cheapest
    @State private var isAddingShop = false
    private var journeys: Journeys { .shared }

    var body: some View {
        let comparison = StoreComparison(items: items, stores: stores, origin: journeys.location)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if stores.isEmpty {
                    EmptyState(
                        systemImage: "storefront",
                        title: "Add the shops you use",
                        message: "Once you’ve added a couple of shops and bought a few things at each, this shows where your list costs least, and what a longer trip would save."
                    ) {
                        Button("Add a Shop") { isAddingShop = true }
                            .buttonStyle(.primary)
                    }
                    .card()
                } else if comparison.options.allSatisfy({ $0.pricedCount == 0 }) {
                    noPrices
                } else {
                    content(comparison)
                }
            }
            .padding()
        }
        .canvasBackground()
        .task { await journeys.locate() }
        #if DEBUG
        .onAppear {
            if let debugGoal = DebugLaunch.goal { goal = debugGoal }
        }
        #endif
        .sheet(isPresented: $isAddingShop) {
            if let household = list.household {
                NavigationStack {
                    AddShopView(household: household, onAdded: { _ in isAddingShop = false })
                }
            }
        }
    }

    private var noPrices: some View {
        EmptyState(
            systemImage: "tag",
            title: "No prices yet",
            message: "Prices are saved as you shop: choose the shop you’re in, then tick things off. Once a shop has prices for things on this list, you’ll see what it costs there."
        )
        .card()
    }

    /// Closest needs to know where you are.
    private func goals(_ comparison: StoreComparison) -> [ShoppingPlan.Goal] {
        ShoppingPlan.Goal.allCases.filter { $0 != .closest || comparison.nearest != nil }
    }

    @ViewBuilder
    private func content(_ comparison: StoreComparison) -> some View {
        if journeys.access != .allowed {
            LocationBanner(message: "See how far each shop is, which is nearest, and the best way round them.")
                .card()
        }

        if let best = comparison.bestSaving, let nearest = comparison.nearest {
            InsightCard(saving: best.saving, store: best.option.store, nearest: nearest)
        }

        let goals = goals(comparison)
        if stores.count > 1 {
            ChipPicker(options: goals.map { ($0, $0.title) }, selection: $goal)
        }

        let chosen = stores.count == 1 ? .fewestStops : goals.contains(goal) ? goal : .cheapest
        if let plan = ShoppingPlan(goal: chosen, comparison: comparison) {
            RouteSection(plan: plan, stores: stores, onStartShopping: onStartShopping)
        } else {
            Text("None of these shops has prices for things on this list yet.")
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
                .card()
        }

        let notSold = comparison.notSoldAnywhere
        let unpriced = comparison.unpriced.filter { !notSold.contains($0) }
        if !notSold.isEmpty {
            NotSoldCard(items: notSold)
        }
        if !unpriced.isEmpty {
            UnpricedCard(items: unpriced)
        }

        if stores.count == 1 {
            Text("Add another shop to compare prices between them.")
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
                .card()
        }
    }
}

/// The trade-off the app exists to show: a longer trip, and what it saves.
private struct InsightCard: View {
    let saving: StoreComparison.Saving
    let store: Store
    let nearest: Store
    private var journeys: Journeys { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Worth the trip?", systemImage: "lightbulb")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.onBrand.opacity(0.85))
            Text("Save \(Money.format(saving.amountMinor)) at \(store.name ?? "")")
                .font(.title2.bold())
                .foregroundStyle(Color.onBrand)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.onBrand.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .task(id: JourneyKey(location: journeys.location, store: store)) {
            await journeys.load(to: [nearest, store])
        }
    }

    private var detail: String {
        let things = saving.commonCount == 1
            ? String(localized: "the 1 thing priced at both")
            : String(localized: "the \(saving.commonCount) things priced at both")
        let nearestName = nearest.name ?? ""
        guard let there = journeys.fromHere(to: store), let nearby = journeys.fromHere(to: nearest) else {
            return String(localized: "Compared with \(nearestName), your nearest shop, on \(things).")
        }
        let extra = there.driveMinutes - nearby.driveMinutes
        if extra > 0 {
            return String(localized: "\(Journey.format(minutes: extra)) further by car than \(nearestName), on \(things).")
        }
        return String(localized: "Compared with \(nearestName), on \(things), and it’s no further away.")
    }
}

/// The plan's stops in the order to visit them, each with the leg that gets
/// you there, and the map.
private struct RouteSection: View {
    let plan: ShoppingPlan
    let stores: [Store]
    let onStartShopping: (Store) -> Void
    private var journeys: Journeys { .shared }

    /// The leg to each stop: from you to the first, then from stop to stop.
    private var legs: [Journey?] {
        plan.stops.indices.map { index in
            index == 0
                ? journeys.location.flatMap { _ in journeys.fromHere(to: plan.stops[0].store) }
                : journeys.between(plan.stops[index - 1].store, and: plan.stops[index].store)
        }
    }

    var body: some View {
        let legs = legs
        let total = legs.allSatisfy { $0 != nil } ? legs.compactMap(\.self).reduce(Journey(driveMinutes: 0, walkMinutes: 0), +) : nil
        PlanSummary(plan: plan, total: total)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(plan.stops.enumerated()), id: \.element.id) { index, stop in
                LegRow(
                    from: index == 0 ? nil : plan.stops[index - 1].store.name,
                    leg: legs[index],
                    isLocationOff: index == 0 && journeys.access != .allowed
                )
                StopCard(number: plan.stops.count > 1 ? index + 1 : nil, stop: stop)
            }
        }
        RouteMap(stops: plan.stops, stores: stores)
            .task(id: RouteKey(location: journeys.location, stops: plan.stops.map(\.id))) {
                await journeys.load(route: plan.stops.map(\.store))
            }
        if let first = plan.stops.first {
            Button {
                onStartShopping(first.store)
            } label: {
                Label("Start Shopping at \(first.store.name ?? "")", systemImage: "basket")
            }
            .buttonStyle(.primary)
        }
    }
}

private struct RouteKey: Hashable {
    let location: CLLocation?
    let stops: [NSManagedObjectID]
}

private struct PlanSummary: View {
    let plan: ShoppingPlan
    /// The whole route, once every leg is known.
    let total: Journey?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(plan.stops.count == 1 ? String(localized: "1 shop") : String(localized: "\(plan.stops.count) shops"))
                    .font(.title2.bold())
                    .foregroundStyle(Color.ink)
                Spacer()
                HeroAmount(minorUnits: plan.totalMinor, size: 28)
            }
            Text(plan.pricedCount == plan.itemCount
                 ? String(localized: "All \(plan.itemCount) items")
                 : String(localized: "\(plan.pricedCount) of \(plan.itemCount) items priced"))
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
            if let total {
                Text("\(Image(systemName: "car")) \(Journey.format(minutes: total.driveMinutes)) or \(Image(systemName: "figure.walk")) \(Journey.format(minutes: total.walkMinutes)) in total")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityLabel("\(Journey.format(minutes: total.driveMinutes)) by car or \(Journey.format(minutes: total.walkMinutes)) on foot in total")
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// How you get to the next stop: from where you are, or from the shop before.
private struct LegRow: View {
    /// The shop before, or nil when you set off from where you are.
    let from: String?
    let leg: Journey?
    let isLocationOff: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down")
                .accessibilityHidden(true)
            if isLocationOff {
                Text("Turn on Location to see the way there")
            } else {
                Text(from.map { String(localized: "From \($0)") } ?? String(localized: "From you"))
                    .lineLimit(1)
                Spacer(minLength: 4)
                JourneyLabel(journey: leg)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color.inkSecondary)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

private struct StopCard: View {
    let number: Int?
    let stop: ShoppingPlan.Stop
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    if let number {
                        Text(number, format: .number)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.onBrand)
                            .frame(width: 26, height: 26)
                            .background(Color.brand, in: .circle)
                    }
                    StoreBadge(store: stop.store, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.store.name ?? "")
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                        if let address = stop.store.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(Color.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Money.format(stop.totalMinor))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(Color.ink)
                        Text(stop.items.count == 1 ? "1 item" : "\(stop.items.count) items")
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(stop.items, id: \.objectID) { item in
                        HStack(spacing: 10) {
                            ProductIcon(product: item.product)
                                .foregroundStyle(Color.inkSecondary)
                                .frame(width: 24)
                            Text(item.displayName)
                            if item.quantity > 1 {
                                Text("×\(item.quantity)").foregroundStyle(Color.inkSecondary)
                            }
                            Spacer()
                            if let price = item.product?.latestPrice(at: stop.store) {
                                Text(Money.format(price.amountMinor * Int64(item.quantity)))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.inkSecondary)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                    }
                }
                .padding(.leading, number == nil ? 0 : 38)
            }
        }
        .card()
    }
}

private struct RouteMap: View {
    let stops: [ShoppingPlan.Stop]
    /// All the household's shops, to tell when a name needs its address.
    let stores: [Store]
    @State private var position: MapCameraPosition

    init(stops: [ShoppingPlan.Stop], stores: [Store]) {
        self.stops = stops
        self.stores = stores
        _position = State(initialValue: Self.framing(stops))
    }

    /// The plan's shops with room around them. Never closer than about
    /// 1.5 km across, so a single shop shows its neighbourhood.
    static func framing(_ stops: [ShoppingPlan.Stop]) -> MapCameraPosition {
        let coordinates = stops.map(\.store.coordinate)
        guard let first = coordinates.first else { return .automatic }
        let latitudes = coordinates.map(\.latitude), longitudes = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (latitudes.min()! + latitudes.max()!) / 2,
            longitude: (longitudes.min()! + longitudes.max()!) / 2
        )
        let minimumDegrees = 0.014
        let longitudeScale = max(0.2, cos(first.latitude * .pi / 180))
        let span = MKCoordinateSpan(
            latitudeDelta: max(minimumDegrees, (latitudes.max()! - latitudes.min()!) * 1.6),
            longitudeDelta: max(minimumDegrees / longitudeScale, (longitudes.max()! - longitudes.min()!) * 1.6)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Map(position: $position, interactionModes: [.pan, .zoom]) {
                UserAnnotation()
                ForEach(stops) { stop in
                    Marker(label(for: stop.store), monogram: Text(String((stop.store.name ?? "").prefix(1))), coordinate: stop.store.coordinate)
                        .tint(stop.store.color)
                }
            }
            .frame(height: 180)
            // A different plan has different shops: frame them, even if
            // you'd moved the map.
            .onChange(of: stops.map(\.id)) {
                withAnimation { position = Self.framing(stops) }
            }

            Button {
                openInMaps()
            } label: {
                Label("Directions in Maps", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
        }
        .background(Color.surface)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }

    /// The shop's name, with its address when another shop shares the name.
    private func label(for store: Store) -> String {
        let name = store.name ?? ""
        guard store.sharesName(with: stores), let address = store.address else { return name }
        return "\(name), \(address)"
    }

    private func openInMaps() {
        guard let stop = stops.first else { return }
        let item = MKMapItem(location: stop.store.location, address: nil)
        item.name = stop.store.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}

private struct NotSoldCard: View {
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(items.count == 1 ? "1 item isn’t sold at your shops" : "\(items.count) items aren’t sold at your shops")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text(items.map(\.displayName).formatted(.list(type: .and)))
                .font(.subheadline)
                .foregroundStyle(Color.ink)
            Text("Every shop you’ve added has been marked as not selling these. Add a shop that does from the Shops tab.")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .card()
    }
}

private struct UnpricedCard: View {
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(items.count == 1 ? "1 item has no price yet" : "\(items.count) items have no price yet")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text(items.map(\.displayName).formatted(.list(type: .and)))
                .font(.subheadline)
                .foregroundStyle(Color.ink)
            Text("You’ll be asked for a price the first time you tick each one off in a shop.")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .card()
    }
}
