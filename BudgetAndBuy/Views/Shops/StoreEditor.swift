import CoreData
import MapKit
import SwiftUI

/// Edits a shop's name, colour and location. Any shop can be renamed: two
/// can share a name, told apart by their addresses.
struct StoreEditor: View {
    private let store: Store
    private let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var name: String
    @State private var colorName: String
    @State private var place: ShopPlace
    @State private var isPickingLocation = false
    @AppStorage(StoreArrivalMonitor.enabledKey) private var noticesArrivals = false
    @State private var isConfirmingDeletion = false

    init(store: Store, onDelete: @escaping () -> Void = {}) {
        self.store = store
        self.onDelete = onDelete
        _name = State(initialValue: store.name ?? "")
        _colorName = State(initialValue: store.colorName ?? "slate")
        _place = State(initialValue: store.place)
    }

    private var trimmedName: String { ProductName.display(name) }

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
                            .fill(ListAppearance.color(named: name))
                            .accessibilityLabel(ListAppearance.title(named: name))
                    }
                }
                .onSurface()

                Section {
                    Map(position: .constant(.region(MKCoordinateRegion(
                        center: place.coordinate, latitudinalMeters: 400, longitudinalMeters: 400
                    ))), interactionModes: []) {
                        Marker(trimmedName, systemImage: "storefront", coordinate: place.coordinate)
                            .tint(ListAppearance.color(named: colorName))
                    }
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                    Text(place.fullAddress)
                        .foregroundStyle(Color.ink)
                    Button("Change Location…") { isPickingLocation = true }
                    Toggle("Start Shopping When I Arrive", isOn: Binding(
                        get: { noticesArrivals },
                        set: { enabled in Task { await StoreArrivalMonitor.shared.setEnabled(enabled) } }
                    ))
                    .tint(.brand)
                } header: {
                    Text("Location")
                } footer: {
                    Text("When you arrive at one of your shops, Budget & Buy gets your list ready to shop there and lets you know. Applies to all your shops. Your location is only checked on your iPhone.")
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
                ShopLocationSheet(storeName: trimmedName, place: place) { picked in
                    place = picked
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
        if place != target.place { target.place = place }
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
