import CoreData
import SwiftUI

enum AppTab: String, Hashable {
    case lists, shops, savings, household
}

/// The app's four places: lists, the shops you use, what you've saved, and
/// who you share with.
struct MainTabView: View {
    @ObservedObject var household: Household
    let households: [Household]
    @Binding var selectedHouseholdID: String

    @SceneStorage("selectedTab") private var tab: AppTab = .lists

    var body: some View {
        TabView(selection: $tab) {
            Tab("Lists", systemImage: "checklist", value: AppTab.lists) {
                ListsScreen(household: household, households: households, selectedHouseholdID: $selectedHouseholdID, tab: $tab)
            }
            Tab("Shops", systemImage: "storefront", value: AppTab.shops) {
                ShopsScreen(household: household)
            }
            Tab("Savings", systemImage: "leaf", value: AppTab.savings) {
                SavingsScreen(household: household)
            }
            Tab("Household", systemImage: "person.2", value: AppTab.household) {
                HouseholdScreen(household: household)
            }
        }
        .tint(.brandInk)
        // The tab bar stays put when you open a list, so nothing pops in and
        // out; it shrinks out of the way as you scroll down instead.
        .tabBarMinimizeBehavior(.onScrollDown)
        #if DEBUG
        .onAppear {
            if let debugTab = DebugLaunch.tab {
                tab = debugTab
            } else if DebugLaunch.opensFirstList || DebugLaunch.opensLastList {
                tab = .lists
            }
        }
        #endif
    }
}
