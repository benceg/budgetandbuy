import CoreData
import SwiftUI

/// Creates a list, or edits one's name, colour and symbol.
struct ListEditor: View {
    private let household: Household?
    private let list: ShoppingList?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var name: String
    @State private var colorName: String
    @State private var symbolName: String
    @FocusState private var isNameFocused: Bool

    init(household: Household) {
        self.household = household
        list = nil
        _name = State(initialValue: "")
        _colorName = State(initialValue: "green")
        _symbolName = State(initialValue: "cart.fill")
    }

    init(list: ShoppingList) {
        household = nil
        self.list = list
        _name = State(initialValue: list.name ?? "")
        _colorName = State(initialValue: list.colorName ?? "green")
        _symbolName = State(initialValue: list.symbol)
    }

    private var trimmedName: String { ProductName.display(name) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 20) {
                        ListIcon(symbolName: symbolName, color: ListAppearance.color(named: colorName), size: 96)
                        TextField("List Name", text: $name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(ListAppearance.color(named: colorName))
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
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
                    SwatchGrid(items: ListAppearance.symbolNames, selection: $symbolName) { name in
                        Image(systemName: name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.tertiarySystemFill), in: .circle)
                    }
                }
            }
            .navigationTitle(list == nil ? "New List" : "List Info")
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
                if list == nil { isNameFocused = true }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty, let target = list ?? household?.addList() else { return }
        target.name = trimmedName
        target.colorName = colorName
        target.symbolName = symbolName
        context.saveIfNeeded()
        dismiss()
    }
}

/// A grid of circular choices with a ring around the selected one.
struct SwatchGrid<Swatch: View>: View {
    let items: [String]
    @Binding var selection: String
    @ViewBuilder let swatch: (String) -> Swatch

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
            ForEach(items, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    swatch(item)
                        .frame(width: 38, height: 38)
                        .padding(4)
                        .overlay {
                            if item == selection {
                                Circle().strokeBorder(Color(.systemGray3), lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    ListEditor(household: PersistenceController.preview.ensureHousehold())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
