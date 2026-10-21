import CoreData
import SwiftUI

/// Settings for the app on this device: how it looks, how lists show their
/// items, shopping on arrival, and help.
struct SettingsScreen: View {
    /// The household the developer tools act on.
    @ObservedObject var household: Household

    @AppStorage(StoreArrivalMonitor.enabledKey) private var noticesArrivals = false
    @AppStorage("groupsByAisle") private var groupsByAisle = true
    @AppStorage(ItemLayout.storageKey) private var itemLayout: ItemLayout = .list
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = true
    @State private var isShowingHowItWorks = false
    #if DEBUG
    @State private var isConfirmingExampleData = false
    @State private var isConfirmingErase = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AppearancePicker()
                } header: {
                    SectionHeading(title: "Appearance").textCase(nil)
                }
                .onSurface()

                Section {
                    Picker("Show Items As", selection: $itemLayout) {
                        ForEach(ItemLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                    Toggle("Group by Aisle", isOn: $groupsByAisle)
                } header: {
                    SectionHeading(title: "Lists").textCase(nil)
                }
                .tint(.brand)
                .onSurface()

                Section {
                    Toggle("Start Shopping When I Arrive", isOn: Binding(
                        get: { noticesArrivals },
                        set: { enabled in Task { await StoreArrivalMonitor.shared.setEnabled(enabled) } }
                    ))
                } header: {
                    SectionHeading(title: "Shopping").textCase(nil)
                } footer: {
                    Text("Your iPhone notices when you reach one of your shops, in any household, and gets your list ready. Your location stays on your iPhone.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .tint(.brand)
                .onSurface()

                Section {
                    Button("How Budget & Buy Works") { isShowingHowItWorks = true }
                    Button("Show the Introduction Again") { hasCompletedOnboarding = false }
                    NavigationLink("Icon Licences") { LicencesView() }
                } header: {
                    SectionHeading(title: "Help").textCase(nil)
                }
                .foregroundStyle(Color.ink)
                .onSurface()

                #if DEBUG
                Section {
                    Button("Load Example Shops and List") { isConfirmingExampleData = true }
                        .foregroundStyle(Color.brandInk)
                    Button("Erase All Data", role: .destructive) { isConfirmingErase = true }
                        .foregroundStyle(Color.apricot)
                } header: {
                    SectionHeading(title: "Developer").textCase(nil)
                } footer: {
                    Text("Both act on “\(household.name ?? "")”, the household you used last. Load adds Aldi, Sainsbury’s, Tesco Express and Waitrose around Coulsdon with a fortnight of prices, and an example weekly list. Erase deletes every list, product, price, shop and trip in it. Only in development builds.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .onSurface()
                #endif
            }
            .themedList()
            .navigationTitle("Settings")
            .sheet(isPresented: $isShowingHowItWorks) {
                HowItWorksSheet()
            }
            #if DEBUG
            .confirmationDialog("Load example data into “\(household.name ?? "")”?", isPresented: $isConfirmingExampleData, titleVisibility: .visible) {
                Button("Load Example Data") { ExampleData.load(into: household) }
            } message: {
                Text("It syncs to iCloud like anything else you add, including to anyone you share the household with.")
            }
            .confirmationDialog("Erase everything in “\(household.name ?? "")”?", isPresented: $isConfirmingErase, titleVisibility: .visible) {
                Button("Erase All Data", role: .destructive) { ExampleData.erase(household) }
            } message: {
                Text("Every list, product, price, shop and trip in it is deleted, on all your devices and for everyone the household is shared with. This can’t be undone.")
            }
            #endif
        }
    }
}
