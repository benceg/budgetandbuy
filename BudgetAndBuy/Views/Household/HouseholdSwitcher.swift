import CoreData
import SwiftUI

extension View {
    /// Shows which household a screen is about under its title, and lets the
    /// title switch to another.
    func householdSwitcher(_ household: Household, households: [Household], selection: Binding<String>) -> some View {
        self
            .navigationSubtitle(households.count > 1 ? household.name ?? "" : "")
            .toolbarTitleMenu {
                if households.count > 1 {
                    Picker("Household", selection: selection) {
                        ForEach(HouseholdSelection.sorted(households), id: \.objectID) { household in
                            Text(household.name ?? "").tag(household.uuid?.uuidString ?? "")
                        }
                    }
                }
            }
    }
}
