import CoreData
import MapKit
import SwiftUI

/// Finds a shop to add: shops near you straight away, or search Maps by name.
/// Present it inside a NavigationStack.
struct AddShopView: View {
    let household: Household
    var canCancel = true
    let onAdded: (Store) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var finder = ShopFinder()
    @State private var query = ""
    @State private var chosen: ShopChoice?

    private var places: [MKMapItem] { query.isEmpty ? finder.nearby : finder.results }

    var body: some View {
        List {
            if finder.access != .allowed && query.isEmpty {
                Section {
                    locationPrompt
                }
                .onSurface()
            }

            if !places.isEmpty {
                Section {
                    ForEach(places, id: \.self) { place in
                        Button { chosen = ShopChoice(place: place) } label: {
                            PlaceRow(place: place, distance: finder.distance(to: place))
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(query.isEmpty ? "Near You" : "Results")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                        .textCase(nil)
                }
                .onSurface()
            } else if !query.isEmpty && !finder.isSearching {
                Section {
                    Text("No shops called “\(query)” nearby.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .onSurface()
            }

            Section {
                Button {
                    chosen = ShopChoice(name: query)
                } label: {
                    Label(query.isEmpty ? "Add a Shop by Name" : "Add “\(query)” by Name", systemImage: "character.cursor.ibeam")
                        .foregroundStyle(Color.brandInk)
                }
            } footer: {
                Text("Without a location, you’ll enter the journey yourself, and the app can’t tell when you arrive.")
                    .foregroundStyle(Color.inkSecondary)
            }
            .onSurface()
        }
        .themedList()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search shops and supermarkets")
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await finder.search(query)
        }
        .task {
            await finder.start()
        }
        .navigationTitle("Add a Shop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .navigationDestination(item: $chosen) { choice in
            ShopSetupView(household: household, choice: choice, finder: finder, onAdded: onAdded)
        }
    }

    @ViewBuilder
    private var locationPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Shops near you", systemImage: "location")
                .font(.headline)
                .foregroundStyle(Color.ink)
            if finder.access == .denied {
                Text("Location is turned off for Budget & Buy, so search for your shop by name instead. You can turn it on in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            } else {
                Text("Allow your location to see shops nearby and how long it takes to get to each. It stays on your iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                ProgressView()
            }
        }
        .padding(.vertical, 6)
    }
}

/// A shop picked from Maps, or one to enter by name.
struct ShopChoice: Hashable {
    let place: MKMapItem?
    let name: String

    init(place: MKMapItem) {
        self.place = place
        name = place.name ?? ""
    }

    init(name: String) {
        place = nil
        self.name = name
    }
}

private struct PlaceRow: View {
    let place: MKMapItem
    let distance: CLLocationDistance?

    var body: some View {
        HStack(spacing: 12) {
            StoreBadge(name: place.name, colorName: "green", size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name ?? "")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                if let address = place.shortAddress {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let distance {
                Text(Measurement(value: distance, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

/// Names the shop and settles how you get there, with the journey worked out
/// by Maps where it can be.
struct ShopSetupView: View {
    let household: Household
    let choice: ShopChoice
    let finder: ShopFinder
    let onAdded: (Store) -> Void

    @Environment(\.managedObjectContext) private var context
    @State private var name: String
    @State private var colorName: String
    @State private var travel: TravelMode
    @State private var minutes = 10
    @State private var kilometres: Double = 0
    @State private var isEstimated = false

    init(household: Household, choice: ShopChoice, finder: ShopFinder, onAdded: @escaping (Store) -> Void) {
        self.household = household
        self.choice = choice
        self.finder = finder
        self.onAdded = onAdded
        _name = State(initialValue: ShopSetupView.shortName(choice.name))
        let used = Set((household.stores ?? []).compactMap(\.colorName))
        _colorName = State(initialValue: ListAppearance.colorNames.first { !used.contains($0) } ?? "blue")
        _travel = State(initialValue: choice.place.map(finder.likelyMode(to:)) ?? .drive)
    }

    private var trimmedName: String { ProductName.display(name) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 14) {
                    StoreBadge(name: trimmedName.isEmpty ? "?" : trimmedName, colorName: colorName, size: 72)
                    TextField("Shop Name", text: $name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.ink)
                        .padding(.vertical, 12)
                        .background(Color.sunken, in: .rect(cornerRadius: 14))
                        .submitLabel(.done)
                    if let address = choice.place?.shortAddress {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    colours
                }
                .card()

                journey

                if let place = choice.place {
                    Map(initialPosition: .region(MKCoordinateRegion(center: place.location.coordinate, latitudinalMeters: 600, longitudinalMeters: 600)), interactionModes: []) {
                        Marker(trimmedName, coordinate: place.location.coordinate)
                            .tint(ListAppearance.color(named: colorName))
                    }
                    .frame(height: 150)
                    .clipShape(.rect(cornerRadius: 22, style: .continuous))
                }

                Button("Add Shop", action: save)
                    .buttonStyle(.primary)
                    .disabled(trimmedName.isEmpty)
            }
            .padding()
        }
        .canvasBackground()
        .navigationTitle("New Shop")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: travel) { await estimate() }
    }

    private var colours: some View {
        HStack(spacing: 10) {
            ForEach(ListAppearance.colorNames.prefix(8), id: \.self) { name in
                Button {
                    colorName = name
                } label: {
                    Circle()
                        .fill(ListAppearance.color(named: name))
                        .frame(width: 28, height: 28)
                        .padding(3)
                        .overlay {
                            if name == colorName { Circle().strokeBorder(Color.ink.opacity(0.4), lineWidth: 2) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name.capitalized)
                .accessibilityAddTraits(name == colorName ? .isSelected : [])
            }
        }
    }

    private var journey: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How do you usually get there?")
                .font(.headline)
                .foregroundStyle(Color.ink)
            ChipPicker(options: TravelMode.allCases.map { ($0, $0.shortTitle) }, selection: $travel)
            Stepper(value: $minutes, in: 1...240) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(travel.journey(minutes: Int16(minutes)))
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.ink)
                    if kilometres > 0 {
                        Text(Measurement(value: kilometres, unit: UnitLength.kilometers), format: .measurement(width: .abbreviated, usage: .road))
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            Text(isEstimated
                 ? "Worked out from where you are now. Adjust it if you usually set off from somewhere else."
                 : "One way, from home. It’s weighed against what a shop saves you, and used to estimate the carbon of the trip.")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func estimate() async {
        guard let place = choice.place, let journey = await finder.journey(to: place, by: travel) else { return }
        minutes = journey.minutes
        kilometres = journey.kilometres
        isEstimated = true
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let store = household.addStore()
        store.name = trimmedName
        store.colorName = colorName
        store.travel = travel
        store.travelMinutes = Int16(minutes)
        store.distanceKm = kilometres
        store.coordinate = choice.place?.location.coordinate
        context.saveIfNeeded()
        Task { await StoreArrivalMonitor.shared.refresh() }
        onAdded(store)
    }

    /// "Aldi Bermondsey" is most likely just "Aldi" to you; keep the brand.
    static func shortName(_ name: String) -> String {
        let brands = ["Aldi", "Lidl", "Tesco", "Sainsbury’s", "Sainsbury's", "Asda", "Morrisons", "Waitrose", "Co-op", "Iceland", "M&S", "Marks & Spencer", "Boots", "Superdrug", "Spar", "Costco", "Ocado", "Home Bargains", "B&M", "Poundland"]
        return brands.first { name.localizedStandardRange(of: $0)?.lowerBound == name.startIndex } ?? name
    }
}

extension TravelMode {
    var shortTitle: LocalizedStringResource {
        switch self {
        case .walk: "Walk"
        case .cycle: "Cycle"
        case .drive: "Drive"
        case .transit: "Bus"
        }
    }
}
