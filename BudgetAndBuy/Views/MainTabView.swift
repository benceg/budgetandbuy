import CoreData
import SwiftUI

enum AppTab: String, Hashable {
    case home, shops, savings, settings
}

/// The app's four places: every household's lists, the current household's
/// shops and savings, and settings.
struct MainTabView: View {
    let households: [Household]
    @Binding var selectedHouseholdID: String

    @SceneStorage("selectedTab") private var tab: AppTab = .home

    /// The household Shops and Savings show: the one last used.
    private var current: Household? {
        HouseholdSelection.preferred(from: households, selectedID: selectedHouseholdID)
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeScreen(households: households, selectedHouseholdID: $selectedHouseholdID, tab: $tab)
            }
            if let current {
                Tab("Shops", systemImage: "storefront", value: AppTab.shops) {
                    // A new identity per household, so the screen fetches its shops.
                    ShopsScreen(household: current, households: households, selectedHouseholdID: $selectedHouseholdID)
                        .id(current.objectID)
                }
                Tab("Savings", systemImage: "leaf", value: AppTab.savings) {
                    SavingsScreen(household: current, households: households, selectedHouseholdID: $selectedHouseholdID)
                        .id(current.objectID)
                }
                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    SettingsScreen(household: current)
                }
            }
        }
        .tint(.brandInk)
        #if DEBUG
        .onAppear {
            if let debugTab = DebugLaunch.tab {
                tab = debugTab
            } else if DebugLaunch.opensFirstList || DebugLaunch.opensLastList {
                tab = .home
            }
        }
        #endif
    }
}
