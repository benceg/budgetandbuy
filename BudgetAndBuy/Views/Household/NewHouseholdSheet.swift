import CoreData
import SwiftUI

/// Makes a household, such as one for someone you care for, optionally
/// starting with another household's shops and prices.
struct NewHouseholdSheet: View {
    /// Households whose shops can be copied.
    let households: [Household]
    let onCreate: (Household) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.persistence) private var persistence
    @Environment(\.managedObjectContext) private var context
    @State private var name = ""
    @State private var colorName = "teal"
    @State private var source: Household?
    @State private var copiesPrices = true
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String { ProductName.display(name) }

    /// Households that have shops to copy.
    private var sources: [Household] {
        HouseholdSelection.sorted(households.filter { !($0.stores ?? []).isEmpty })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 18) {
                        Image(systemName: "house")
                            .font(.system(size: 34))
                            .foregroundStyle(ListAppearance.foreground(named: colorName))
                            .frame(width: 84, height: 84)
                            .background(ListAppearance.color(named: colorName), in: .circle)
                        TextField("Household Name", text: $name, prompt: Text("e.g. Granny’s House"))
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.ink)
                            .padding(.vertical, 12)
                            .background(Color.sunken, in: .rect(cornerRadius: 14))
                            .focused($isNameFocused)
                            .submitLabel(.done)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } footer: {
                    Text("Each household has its own lists, shops and prices, and is shared only with the people you invite to it.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .onSurface()

                Section {
                    SwatchGrid(items: ListAppearance.colorNames, selection: $colorName) { name in
                        Circle()
                            .fill(ListAppearance.color(named: name))
                            .accessibilityLabel(ListAppearance.title(named: name))
                    }
                } header: {
                    SectionHeading(title: "Colour").textCase(nil)
                }
                .onSurface()

                if !sources.isEmpty {
                    Section {
                        Picker("Copy Shops From", selection: $source) {
                            Text("Nowhere").tag(Household?.none)
                            ForEach(sources, id: \.objectID) { household in
                                Text(household.name ?? "").tag(Optional(household))
                            }
                        }
                        if source != nil {
                            Toggle("Include Prices", isOn: $copiesPrices)
                                .tint(.brand)
                        }
                    } header: {
                        SectionHeading(title: "Start With").textCase(nil)
                    } footer: {
                        Text(source == nil
                             ? "Start empty, or copy the shops you’ve already set up in another household."
                             : copiesPrices
                                ? "Copies the shops, every price seen at them and what they don’t sell. Lists and trips aren’t copied."
                                : "Copies the shops, where they are and how you get there, without their prices.")
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .onSurface()
                }
            }
            .themedList()
            .navigationTitle("New Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(trimmedName.isEmpty || persistence == nil)
                }
            }
            .onAppear { isNameFocused = true }
        }
    }

    private func create() {
        guard let persistence, !trimmedName.isEmpty else { return }
        let household = persistence.createHousehold(named: trimmedName, colorName: colorName)
        if let source {
            household.copyShops(from: source, includingPrices: copiesPrices)
        }
        context.saveIfNeeded()
        Task { await StoreArrivalMonitor.shared.refresh() }
        dismiss()
        onCreate(household)
    }
}
