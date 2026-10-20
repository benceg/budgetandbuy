import CoreData
import SwiftUI

@main
struct BudgetAndBuyApp: App {
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
        }
    }
}

struct RootView: View {
    @FetchRequest(sortDescriptors: Household.oldestFirst)
    private var households: FetchedResults<Household>

    var body: some View {
        if let household = households.first {
            ListsView(household: household)
        } else {
            ProgressView()
        }
    }
}
