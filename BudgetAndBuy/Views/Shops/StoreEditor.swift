import CoreData
import MapKit
import SwiftUI

/// Edits a shop's name, colour, location and how you get there.
struct StoreEditor: View {
    private let store: Store
    private let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var name: String
    @State private var colorName: String
    @State private var travel: TravelMode
    @State private var minutes: Int
    @State private var distanceText: String
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isPickingLocation = false
    @AppStorage(StoreArrivalMonitor.enabledKey) private var noticesArrivals = false
    @State private var isConfirmingDeletion = false

    /// Distances are stored in kilometres but entered in the local road unit.
    private static let distanceUnit: UnitLength =
        Locale.current.measurementSystem == .metric ? .kilometers : .miles

    init(store: Store, onDelete: @escaping () -> Void = {}) {
        self.store = store
        self.onDelete = onDelete
        _name = State(initialValue: store.name ?? "")
        _colorName = State(initialValue: store.colorName ?? "blue")
        _travel = State(initialValue: store.travel)
        _minutes = State(initialValue: Int(store.travelMinutes))
        let distance = Measurement(value: store.distanceKm, unit: UnitLength.kilometers).converted(to: Self.distanceUnit)
        _distanceText = State(initialValue: store.distanceKm > 0
            ? distance.value.formatted(.number.precision(.fractionLength(0...1)))
            : "")
        _coordinate = State(initialValue: store.coordinate)
    }

    private var trimmedName: String { ProductName.display(name) }

    private var distanceKm: Double {
        let separator = Locale.current.decimalSeparator ?? "."
        let value = Double(distanceText.replacingOccurrences(of: separator, with: ".")) ?? 0
        return Measurement(value: max(0, value), unit: Self.distanceUnit).converted(to: .kilometers).value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 20) {
                        StoreBadge(name: trimmedName.isEmpty ? "?" : trimmedName, colorName: colorName, size: 80)
                        TextField("Shop Name", text: $name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.ink)
                            .padding(.vertical, 12)
                            .background(Color.sunken, in: .rect(cornerRadius: 14))
                            .submitLabel(.done)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .onSurface()

                Section {
                    SwatchGrid(items: ListAppearance.colorNames, selection: $colorName) { name in
                        Circle()
                            .fill(ListAppearance.color(named: name).gradient)
                            .accessibilityLabel(name.capitalized)
                    }
                }
                .onSurface()

                Section {
                    ChipPicker(options: TravelMode.allCases.map { ($0, $0.shortTitle) }, selection: $travel)
                        .listRowSeparator(.hidden)

                    Stepper(value: $minutes, in: 1...240) {
                        LabeledContent("Journey Time", value: String(localized: "\(minutes) min"))
                    }

                    LabeledContent("Distance") {
                        HStack(spacing: 4) {
                            TextField("Optional", text: $distanceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text(Self.distanceUnit.symbol)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Getting There")
                } footer: {
                    Text("From home, one way. Used to weigh up savings against the trip, and to work out the carbon you save by shopping closer to home.")
                }
                .onSurface()

                Section {
                    if let coordinate {
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: coordinate, latitudinalMeters: 400, longitudinalMeters: 400
                        ))), interactionModes: []) {
                            Marker(trimmedName, systemImage: "storefront.fill", coordinate: coordinate)
                                .tint(ListAppearance.color(named: colorName))
                        }
                        .frame(height: 160)
                        .listRowInsets(EdgeInsets())
                        Button("Change Location…") { isPickingLocation = true }
                        Button("Remove Location", role: .destructive) { self.coordinate = nil }
                    } else {
                        Button("Set Location…", systemImage: "mappin.and.ellipse") { isPickingLocation = true }
                    }
                    Toggle("Start Shopping When I Arrive", isOn: Binding(
                        get: { noticesArrivals },
                        set: { enabled in Task { await StoreArrivalMonitor.shared.setEnabled(enabled) } }
                    ))
                    .tint(.forest)
                } header: {
                    Text("Location")
                } footer: {
                    Text("When you arrive at a shop with a location, Budget & Buy gets your list ready to shop there and lets you know. Applies to all your shops. Your location is only checked on your iPhone.")
                }
                .onSurface()

                Section {
                    Button("Delete Shop", role: .destructive) { isConfirmingDeletion = true }
                        .foregroundStyle(Color.apricot)
                }
                .onSurface()
            }
            .themedList()
            .alert("Delete “\(store.name ?? "")”?", isPresented: $isConfirmingDeletion) {
                Button("Delete", role: .destructive, action: deleteStore)
            } message: {
                Text("This also deletes every price recorded there.")
            }
            .sheet(isPresented: $isPickingLocation) {
                StoreLocationPicker(storeName: trimmedName, initial: coordinate) { picked in
                    coordinate = picked
                }
            }
            .navigationTitle("Edit Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let target = store
        target.name = trimmedName
        target.colorName = colorName
        target.travel = travel
        target.travelMinutes = Int16(minutes)
        target.distanceKm = distanceKm
        target.coordinate = coordinate
        context.saveIfNeeded()
        Task { await StoreArrivalMonitor.shared.refresh() }
        dismiss()
    }

    private func deleteStore() {
        dismiss()
        onDelete()
        context.delete(store)
        context.saveIfNeeded()
        Task { await StoreArrivalMonitor.shared.refresh() }
    }
}
