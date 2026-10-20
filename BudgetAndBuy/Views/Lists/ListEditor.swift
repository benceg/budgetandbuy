import CoreData
import SwiftUI

/// Creates a list, or edits one's name, colour and symbol.
struct ListEditor: View {
    private let household: Household?
    private let list: ShoppingList?
    private var onCreate: (ShoppingList) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var name: String
    @State private var colorName: String
    @State private var symbolName: String
    @FocusState private var isNameFocused: Bool

    init(household: Household, onCreate: @escaping (ShoppingList) -> Void = { _ in }) {
        self.household = household
        self.onCreate = onCreate
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
                            .foregroundStyle(Color.ink)
                            .padding(.vertical, 12)
                            .background(Color.sunken, in: .rect(cornerRadius: 14))
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
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
                    SwatchGrid(items: ListAppearance.symbolNames, selection: $symbolName) { name in
                        Image(systemName: name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.sunken, in: .circle)
                    }
                }
                .onSurface()
            }
            .themedList()
            .navigationTitle(list == nil ? "New List" : "Edit List")
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
        if list == nil { onCreate(target) }
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
                                Circle().strokeBorder(Color.ink.opacity(0.35), lineWidth: 3)
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
