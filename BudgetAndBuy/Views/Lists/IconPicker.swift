import SwiftUI

/// Chooses a product's icon, with the item's own aisle first.
struct IconPicker: View {
    @Binding var selection: GroceryIcon?
    let category: ProductCategory?

    @Environment(\.dismiss) private var dismiss

    private var aisles: [ProductCategory] {
        let others = ProductCategory.allCases.filter { $0 != category }
        return (category.map { [$0] } ?? []) + others
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                Section {
                    cell(nil)
                }
                ForEach(aisles) { aisle in
                    let icons = GroceryIcon.icons(in: aisle)
                    if !icons.isEmpty {
                        Section {
                            ForEach(icons, id: \.self) { icon in
                                cell(icon)
                            }
                        } header: {
                            Text(aisle.title)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cell(_ icon: GroceryIcon?) -> some View {
        let isSelected = icon == selection
        return Button {
            selection = icon
            dismiss()
        } label: {
            Group {
                if let icon {
                    Image(icon.imageName)
                } else {
                    Image(systemName: (category ?? .other).symbolName)
                }
            }
            .font(.title2)
            .frame(width: 56, height: 56)
            .foregroundStyle(isSelected ? Color.onBrand : Color.ink)
            .background(isSelected ? Color.brand : Color.sunken, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.map { Text($0.rawValue.replacing("-", with: " ")) } ?? Text("Aisle Icon"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
