import CoreData
import SwiftUI

struct ListsView: View {
    @ObservedObject var household: Household
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var lists: FetchedResults<ShoppingList>
    @State private var isAddingList = false
    @State private var listPendingDeletion: ShoppingList?

    init(household: Household) {
        self.household = household
        _lists = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "sortOrder", ascending: true)],
            predicate: NSPredicate(format: "household == %@", household),
            animation: .default
        )
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(lists, id: \.objectID) { list in
                    NavigationLink(value: list) {
                        ListRow(list: list)
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            if list.items?.isEmpty ?? true {
                                delete(list)
                            } else {
                                listPendingDeletion = list
                            }
                        }
                    }
                }
                .onMove(perform: move)
            }
            .navigationTitle("Lists")
            .navigationDestination(for: ShoppingList.self) { list in
                ListDetailView(list: list)
            }
            .overlay {
                if lists.isEmpty {
                    ContentUnavailableView {
                        Label("No Lists", systemImage: "cart")
                    } description: {
                        Text("Lists you make appear here.")
                    } actions: {
                        Button("Add List") { isAddingList = true }
                    }
                }
            }
            .toolbar {
                if !lists.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add List", systemImage: "plus") { isAddingList = true }
                }
            }
            .sheet(isPresented: $isAddingList) {
                ListEditor(household: household)
            }
            .alert(
                "Delete “\(listPendingDeletion?.name ?? "")”?",
                isPresented: Binding(
                    get: { listPendingDeletion != nil },
                    set: { if !$0 { listPendingDeletion = nil } }
                ),
                presenting: listPendingDeletion
            ) { list in
                Button("Delete", role: .destructive) { delete(list) }
            } message: { _ in
                Text("This will delete everything on the list.")
            }
        }
    }

    private func delete(_ list: ShoppingList) {
        context.delete(list)
        context.saveIfNeeded()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = Array(lists)
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, list) in reordered.enumerated() {
            list.sortOrder = Double(index)
        }
        context.saveIfNeeded()
    }
}

private struct ListRow: View {
    @ObservedObject var list: ShoppingList
    @FetchRequest private var remaining: FetchedResults<Item>

    init(list: ShoppingList) {
        self.list = list
        _remaining = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "list == %@ AND isChecked == NO", list)
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ListIcon(symbolName: list.symbol, color: list.color)
            Text(list.name ?? "")
            Spacer()
            Text(remaining.count, format: .number)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(remaining.count) to buy")
        }
    }
}

#Preview {
    let persistence = PersistenceController.preview
    ListsView(household: persistence.ensureHousehold())
        .environment(\.managedObjectContext, persistence.viewContext)
}
