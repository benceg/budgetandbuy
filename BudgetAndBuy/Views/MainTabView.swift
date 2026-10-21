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
            Tab(value: AppTab.home) {
                HomeScreen(households: households, selectedHouseholdID: $selectedHouseholdID, tab: $tab)
            } label: {
                tabLabel("Home", symbol: "house", for: .home)
            }
            if let current {
                Tab(value: AppTab.shops) {
                    // A new identity per household, so the screen fetches its shops.
                    ShopsScreen(household: current, households: households, selectedHouseholdID: $selectedHouseholdID)
                        .id(current.objectID)
                } label: {
                    tabLabel("Shops", symbol: "storefront", for: .shops)
                }
                Tab(value: AppTab.savings) {
                    SavingsScreen(household: current, households: households, selectedHouseholdID: $selectedHouseholdID)
                        .id(current.objectID)
                } label: {
                    tabLabel("Savings", symbol: "leaf", for: .savings)
                }
                Tab(value: AppTab.settings) {
                    SettingsScreen(household: current)
                } label: {
                    tabLabel("Settings", symbol: "gearshape", for: .settings)
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

    /// Outlined, except for the selected tab, which is filled.
    private func tabLabel(_ title: LocalizedStringResource, symbol: String, for value: AppTab) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: tab == value ? "\(symbol).fill" : symbol)
                .environment(\.symbolVariants, .none)
        }
    }
}
