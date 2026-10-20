import CoreData
import SwiftUI

@main
struct BudgetAndBuyApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    #if DEBUG
    // Launch with -sampleData to explore the UI with the in-memory preview data.
    private let persistence = ProcessInfo.processInfo.arguments.contains("-sampleData")
        ? PersistenceController.preview
        : PersistenceController.shared
    #else
    private let persistence = PersistenceController.shared
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .environment(\.persistence, persistence)
        }
    }
}

struct RootView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: Household.oldestFirst, animation: .default)
    private var households: FetchedResults<Household>
    @AppStorage("selectedHouseholdID") private var selectedID = ""
    @AppStorage("knownSharedHouseholdIDs") private var knownSharedIDs = ""
    @State private var joinedHousehold: Household?

    private var ownHousehold: Household? {
        households.first { !$0.isSharedWithMe }
    }

    var body: some View {
        Group {
            if let household = HouseholdSelection.preferred(from: Array(households), selectedID: selectedID) {
                ListsView(household: household, households: Array(households), selectedID: $selectedID)
                    .id(household.objectID)
            } else {
                ProgressView()
            }
        }
        .onChange(of: households.map(\.objectID), initial: true) {
            noticeJoinedHouseholds()
        }
        .alert(
            "Move Your Lists to “\(joinedHousehold?.name ?? "")”?",
            isPresented: Binding(
                get: { joinedHousehold != nil },
                set: { if !$0 { joinedHousehold = nil } }
            ),
            presenting: joinedHousehold
        ) { joined in
            Button("Move Lists") {
                ownHousehold?.moveContents(to: joined)
                context.saveIfNeeded()
            }
            Button("Keep Separate", role: .cancel) {}
        } message: { _ in
            Text("Everyone in the household will be able to see and edit them. You can switch between households from the title on the Lists screen.")
        }
    }

    /// When a household someone shared with you first arrives, switch to it and
    /// offer to bring your own lists along.
    private func noticeJoinedHouseholds() {
        var known = Set(knownSharedIDs.split(separator: ",").map(String.init))
        for household in households where household.isSharedWithMe {
            guard let id = household.uuid?.uuidString, !known.contains(id) else { continue }
            known.insert(id)
            selectedID = id
            if !(ownHousehold?.lists?.isEmpty ?? true) {
                joinedHousehold = household
            }
        }
        knownSharedIDs = known.sorted().joined(separator: ",")
    }
}
