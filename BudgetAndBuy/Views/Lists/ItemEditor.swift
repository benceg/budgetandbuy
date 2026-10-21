import CoreData
import SwiftUI

/// Edits an item's name, size, quantity and aisle.
///
/// Name and size identify the product, so changing either points the item at
/// the matching product (created if new) instead of renaming the shared one:
/// prices recorded for "Milk 2 L" stay with "Milk 2 L".
struct ItemEditor: View {
    @ObservedObject var item: Item

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var name: String
    @State private var sizeText: String
    @State private var sizeUnit: ProductSize.Unit?
    @State private var quantity: Int
    @State private var category: ProductCategory?
    @State private var icon: GroceryIcon?

    init(item: Item) {
        self.item = item
        let size = item.product?.size
        _name = State(initialValue: item.product?.name ?? "")
        _sizeText = State(initialValue: size.map { $0.amount.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? "")
        _sizeUnit = State(initialValue: size?.unit)
        _quantity = State(initialValue: Int(item.quantity))
        _category = State(initialValue: item.product?.category)
        _icon = State(initialValue: item.product?.icon)
    }

    private var trimmedName: String { ProductName.display(name) }

    private var size: ProductSize? {
        let separator = Locale.current.decimalSeparator ?? "."
        let amount = Double(sizeText.replacingOccurrences(of: separator, with: ".")) ?? 0
        return ProductSize(amount: amount, unit: sizeUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                .onSurface()

                Section {
                    HStack {
                        TextField("Amount", text: $sizeText)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $sizeUnit) {
                            Text("No Size").tag(ProductSize.Unit?.none)
                            ForEach(ProductSize.Unit.allCases) { unit in
                                Text(unit.title).tag(Optional(unit))
                            }
                        }
                        .labelsHidden()
                    }
                } header: {
                    Text("Size")
                } footer: {
                    Text("Different sizes are priced separately, so “Milk 1 pt” and “Milk 2 L” each keep their own prices.")
                }
                .onSurface()

                Section {
                    Stepper(value: $quantity, in: 1...99) {
                        LabeledContent("Quantity", value: quantity.formatted())
                    }
                    Picker("Aisle", selection: $category) {
                        Text("None").tag(ProductCategory?.none)
                        ForEach(ProductCategory.allCases) { category in
                            Label {
                                Text(category.title)
                            } icon: {
                                Image(category.icon.imageName)
                            }
                            .tag(Optional(category))
                        }
                    }
                    NavigationLink {
                        IconPicker(selection: $icon, category: category)
                    } label: {
                        LabeledContent("Icon") {
                            if let icon {
                                Image(icon.imageName)
                                    .font(.title3)
                            } else {
                                Text("Aisle Icon")
                            }
                        }
                    }
                }
                .onSurface()
            }
            .themedList()
            .navigationTitle("Edit Item")
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
        guard let household = item.list?.household, !trimmedName.isEmpty else { return }
        let previous = item.product
        let product = household.product(named: trimmedName, size: size)
        if product != previous {
            item.product = product
            item.list?.mergeDuplicateItems()
            product.fillInFromCatalogue()
        }
        if category != previous?.category || product.category == nil {
            product.category = category
        }
        if icon != previous?.icon {
            product.icon = icon
        }
        item.quantity = Int16(quantity)
        context.saveIfNeeded()
        ProductCategorizer.shared.categorize([product])
        dismiss()
    }
}
