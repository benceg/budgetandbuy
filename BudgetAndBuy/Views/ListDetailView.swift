import CoreData
import SwiftUI

struct ListDetailView: View {
    @ObservedObject var list: ShoppingList
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var items: FetchedResults<Item>
    @State private var newItemName = ""
    @FocusState private var isAddingItem: Bool
    @State private var isBasketExpanded = true
    @State private var isEditingInfo = false
    @State private var isConfirmingClear = false
    @State private var isConfirmingDeletion = false

    init(list: ShoppingList) {
        self.list = list
        _items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)],
            predicate: NSPredicate(format: "list == %@", list),
            animation: .default
        )
    }

    private var toBuy: [Item] { items.filter { !$0.isChecked } }

    private var inBasket: [Item] {
        items.filter(\.isChecked).sorted { ($0.checkedAt ?? .distantPast) > ($1.checkedAt ?? .distantPast) }
    }

    private var suggestions: [Product] {
        let onList = Set(toBuy.compactMap(\.product))
        return list.household?.products(matching: newItemName, limit: 6)
            .filter { !onList.contains($0) && $0.normalizedName != ProductName.normalized(newItemName) }
            .prefix(3)
            .map(\.self) ?? []
    }

    var body: some View {
        List {
            Section {
                ForEach(toBuy, id: \.objectID) { item in
                    ItemRow(item: item, tint: list.color)
                }
                newItemRow
                ForEach(suggestions, id: \.objectID) { product in
                    Button {
                        list.add(product)
                        context.saveIfNeeded()
                        newItemName = ""
                    } label: {
                        Label(product.name ?? "", systemImage: "plus.circle")
                            .foregroundStyle(list.color)
                    }
                }
            }

            if !inBasket.isEmpty {
                Section(isExpanded: $isBasketExpanded) {
                    ForEach(inBasket, id: \.objectID) { item in
                        ItemRow(item: item, tint: list.color)
                    }
                } header: {
                    basketHeader
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(list.name ?? "")
        .tint(list.color)
        .toolbar { toolbar }
        .sheet(isPresented: $isEditingInfo) {
            ListEditor(list: list)
        }
        .confirmationDialog("Clear the basket?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear \(inBasket.count) Items", role: .destructive, action: clearBasket)
        }
        .alert("Delete “\(list.name ?? "")”?", isPresented: $isConfirmingDeletion) {
            Button("Delete", role: .destructive, action: deleteList)
        } message: {
            Text("This will delete everything on the list.")
        }
    }

    private var newItemRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.title2)
                .foregroundStyle(Color(.quaternaryLabel))
                .accessibilityHidden(true)
            TextField("New Item", text: $newItemName)
                .focused($isAddingItem)
                .submitLabel(.next)
                .onSubmit(addItem)
        }
    }

    private var basketHeader: some View {
        HStack {
            Button {
                withAnimation { isBasketExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("In Basket")
                    Text(inBasket.count, format: .number).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isBasketExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button("Clear") { isConfirmingClear = true }
                .font(.subheadline)
        }
        .font(.headline)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isAddingItem {
                Button("Done") { isAddingItem = false }
            } else {
                Menu("More", systemImage: "ellipsis") {
                    Button("Show List Info", systemImage: "info.circle") { isEditingInfo = true }
                    Button("Clear Basket", systemImage: "basket") { isConfirmingClear = true }
                        .disabled(inBasket.isEmpty)
                    Divider()
                    Button("Delete List", systemImage: "trash", role: .destructive) { isConfirmingDeletion = true }
                }
            }
        }
        ToolbarItem(placement: .bottomBar) {
            Button {
                isAddingItem = true
            } label: {
                Label("New Item", systemImage: "plus.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .fontWeight(.semibold)
            }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
    }

    private func addItem() {
        guard list.addItem(named: newItemName) != nil else {
            // Returning on an empty row ends entry, as in Reminders.
            isAddingItem = false
            return
        }
        context.saveIfNeeded()
        newItemName = ""
        isAddingItem = true
    }

    private func clearBasket() {
        for item in inBasket {
            context.delete(item)
        }
        context.saveIfNeeded()
    }

    private func deleteList() {
        dismiss()
        context.delete(list)
        context.saveIfNeeded()
    }
}

private struct ItemRow: View {
    @ObservedObject var item: Item
    let tint: Color

    var body: some View {
        Button {
            withAnimation {
                item.setChecked(!item.isChecked)
            }
            item.managedObjectContext?.saveIfNeeded()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? tint : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
                Text(item.displayName)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(item.isChecked ? Text("In basket") : Text("To buy"))
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .contextMenu {
            Button("Increase Quantity", systemImage: "plus") { changeQuantity(by: 1) }
            Button("Decrease Quantity", systemImage: "minus") { changeQuantity(by: -1) }
                .disabled(item.quantity <= 1)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
    }

    private func changeQuantity(by delta: Int16) {
        item.quantity = max(1, item.quantity + delta)
        item.managedObjectContext?.saveIfNeeded()
    }

    private func delete() {
        let context = item.managedObjectContext
        context?.delete(item)
        context?.saveIfNeeded()
    }
}

#Preview {
    let persistence = PersistenceController.preview
    NavigationStack {
        ListDetailView(list: persistence.ensureHousehold().addList())
    }
    .environment(\.managedObjectContext, persistence.viewContext)
}
