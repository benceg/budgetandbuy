import CoreData
import SwiftUI

@main
struct BudgetAndBuyApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    #if DEBUG
    private let persistence = DebugLaunch.usesSampleData
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

#if DEBUG
/// Launch arguments for exploring the UI in the simulator:
/// -sampleData uses in-memory sample data (-shopping: shopping at the Co-op) and skips
/// the introduction unless -onboarding is also passed; -tab shops|savings|household
/// picks a tab; -openFirstList (or -openLastList) opens a list; -page plan|budget picks
/// its page (-goal cheapest|fewestStops|closest picks a plan); -openItem opens its first item; -addShop opens Add a Shop;
/// -onboardingStep 1…3 opens the introduction at a later step; -exampleData
/// loads the Coulsdon example shops and list.
enum DebugLaunch {
    private static let arguments = ProcessInfo.processInfo.arguments
    static let usesSampleData = arguments.contains("-sampleData")
    static let showsOnboarding = arguments.contains("-onboarding")
    static let isShopping = arguments.contains("-shopping")
    static let loadsExampleData = arguments.contains("-exampleData")
    static let onboardingStep = UserDefaults.standard.integer(forKey: "onboardingStep")
    static let opensFirstList = arguments.contains("-openFirstList")
    static let opensLastList = arguments.contains("-openLastList")
    static let opensFirstItem = arguments.contains("-openItem")
    static let opensAddShop = arguments.contains("-addShop")
    static let tab = UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init(rawValue:))
    static let page = UserDefaults.standard.string(forKey: "page").flatMap(ListPage.init(rawValue:))
    static let goal = UserDefaults.standard.string(forKey: "goal").flatMap(ShoppingPlan.Goal.init(rawValue:))
}
#endif

struct RootView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: Household.oldestFirst, animation: .default)
    private var households: FetchedResults<Household>
    @AppStorage("selectedHouseholdID") private var selectedID = ""
    @AppStorage("knownSharedHouseholdIDs") private var knownSharedIDs = ""
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false
    @State private var joinedHousehold: Household?

    private var ownHousehold: Household? {
        households.first { !$0.isSharedWithMe }
    }

    var body: some View {
        Group {
            if let household = HouseholdSelection.preferred(from: Array(households), selectedID: selectedID) {
                MainTabView(household: household, households: Array(households), selectedHouseholdID: $selectedID)
                    .id(household.objectID)
                    .fullScreenCover(isPresented: Binding(
                        get: { !hasCompletedOnboarding },
                        set: { if !$0 { hasCompletedOnboarding = true } }
                    )) {
                        OnboardingView(household: household)
                    }
            } else {
                ProgressView()
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        #if DEBUG
        .onAppear {
            if DebugLaunch.usesSampleData { hasCompletedOnboarding = !DebugLaunch.showsOnboarding }
            if DebugLaunch.loadsExampleData, let household = households.first { ExampleData.load(into: household) }
        }
        #endif
        .onChange(of: households.map(\.objectID), initial: true) {
            noticeJoinedHouseholds()
        }
        .task {
            ProductCategorizer.shared.categorizeAll(in: context)
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
            Text("Everyone in the household will be able to see and edit them. You can switch between households from the title on the Lists tab.")
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
