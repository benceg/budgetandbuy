import CoreData
import SwiftUI

/// Creates a store, or edits its name, colour and how you get there.
struct StoreEditor: View {
    private let household: Household?
    private let store: Store?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var name: String
    @State private var colorName: String
    @State private var travel: TravelMode
    @State private var minutes: Int
    @State private var distanceText: String
    @FocusState private var isNameFocused: Bool

    /// Distances are stored in kilometres but entered in the local road unit.
    private static let distanceUnit: UnitLength =
        Locale.current.measurementSystem == .metric ? .kilometers : .miles

    init(household: Household) {
        self.household = household
        store = nil
        _name = State(initialValue: "")
        _colorName = State(initialValue: "blue")
        _travel = State(initialValue: .drive)
        _minutes = State(initialValue: 10)
        _distanceText = State(initialValue: "")
    }

    init(store: Store) {
        household = nil
        self.store = store
        _name = State(initialValue: store.name ?? "")
        _colorName = State(initialValue: store.colorName ?? "blue")
        _travel = State(initialValue: store.travel)
        _minutes = State(initialValue: Int(store.travelMinutes))
        let distance = Measurement(value: store.distanceKm, unit: UnitLength.kilometers).converted(to: Self.distanceUnit)
        _distanceText = State(initialValue: store.distanceKm > 0
            ? distance.value.formatted(.number.precision(.fractionLength(0...1)))
            : "")
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
                        ListIcon(symbolName: "storefront.fill", color: ListAppearance.color(named: colorName), size: 96)
                        TextField("Store Name", text: $name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(ListAppearance.color(named: colorName))
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
                            .focused($isNameFocused)
                            .submitLabel(.done)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    SwatchGrid(items: ListAppearance.colorNames, selection: $colorName) { name in
                        Circle()
                            .fill(ListAppearance.color(named: name).gradient)
                            .accessibilityLabel(name.capitalized)
                    }
                }

                Section {
                    Picker("Travel", selection: $travel) {
                        ForEach(TravelMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
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
            }
            .navigationTitle(store == nil ? "New Store" : "Store Info")
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
            .onAppear {
                if store == nil { isNameFocused = true }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty, let target = store ?? household?.addStore() else { return }
        target.name = trimmedName
        target.colorName = colorName
        target.travel = travel
        target.travelMinutes = Int16(minutes)
        target.distanceKm = distanceKm
        context.saveIfNeeded()
        dismiss()
    }
}

#Preview {
    StoreEditor(household: PersistenceController.preview.ensureHousehold())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
