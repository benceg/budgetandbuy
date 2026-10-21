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
/// the introduction unless -onboarding is also passed; -tab shops|savings|settings
/// picks a tab (home, shops, savings, settings); -openFirstList (or -openLastList) opens a list; -page plan|budget picks
/// its page; -tickFirstItem ticks its first item a second later; -typeItem
/// TEXT types into its add field (-goal cheapest|fewestStops|closest picks a plan); -openItem opens its first item; -addShop opens Add a Shop;
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
    static let opensHouseholdSettings = arguments.contains("-householdSettings")
    static let ticksFirstItem = arguments.contains("-tickFirstItem")
    static let typedItem = UserDefaults.standard.string(forKey: "typeItem")
    static let opensFirstItem = arguments.contains("-openItem")
    static let opensAddShop = arguments.contains("-addShop")
    static let tab = UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init(rawValue:))
    static let page = UserDefaults.standard.string(forKey: "page").flatMap(ListPage.init(rawValue:))
    static let scrollAnchor = UserDefaults.standard.object(forKey: "scrollAnchor") as? Double ?? (UserDefaults.standard.string(forKey: "scrollAnchor")).flatMap(Double.init)
    static let goal = UserDefaults.standard.string(forKey: "goal").flatMap(ShoppingPlan.Goal.init(rawValue:))
}
#endif

struct RootView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: Household.oldestFirst, animation: .default)
    private var households: FetchedResults<Household>
    /// The household used last, which Shops and Savings show.
    @AppStorage("selectedHouseholdID") private var selectedID = ""
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .sage

    var body: some View {
        Group {
            if let current = HouseholdSelection.preferred(from: Array(households), selectedID: selectedID) {
                MainTabView(households: Array(households), selectedHouseholdID: $selectedID)
                    // Colours are read as they're drawn, so a new theme
                    // rebuilds the screens; the selected tab is kept.
                    .id(theme)
                    .fullScreenCover(isPresented: Binding(
                        get: { !hasCompletedOnboarding },
                        set: { if !$0 { hasCompletedOnboarding = true } }
                    )) {
                        OnboardingView(household: current)
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
        .task {
            ProductCategorizer.shared.categorizeAll(in: context)
        }
    }
}
