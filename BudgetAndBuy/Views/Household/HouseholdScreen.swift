import CloudKit
import CoreData
import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Sharing")

/// Who's in the household and how to invite more people, with the app's
/// settings and help.
struct HouseholdScreen: View {
    @ObservedObject var household: Household
    @Environment(\.managedObjectContext) private var context
    @Environment(\.persistence) private var persistence
    @AppStorage(StoreArrivalMonitor.enabledKey) private var noticesArrivals = false
    @AppStorage("groupsByAisle") private var groupsByAisle = true
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = true
    @State private var name = ""
    @State private var share: CKShare?
    @State private var isPreparingShare = false
    @State private var errorMessage: String?
    @State private var sharingDelegate: SharingDelegate?
    @State private var isEditingBudget = false
    @State private var isShowingHowItWorks = false
    #if DEBUG
    @State private var isConfirmingExampleData = false
    #endif

    private var isOwner: Bool { !household.isSharedWithMe }

    private var members: [CKShare.Participant] {
        (share?.participants ?? [])
            .filter { $0.acceptanceStatus != .removed }
            .sorted { ($0.role == .owner ? 0 : 1) < ($1.role == .owner ? 0 : 1) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: "house")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.forestInk)
                            .frame(width: 84, height: 84)
                            .background(Color.sagePale, in: .circle)
                        if isOwner {
                            TextField("Household Name", text: $name)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.ink)
                                .padding(.vertical, 12)
                                .background(Color.sunken, in: .rect(cornerRadius: 14))
                                .submitLabel(.done)
                                .onSubmit(saveName)
                        } else {
                            Text(household.name ?? "")
                                .font(.title2.bold())
                        }
                        Text("Everyone in the household shares its lists, shops and prices, and sees changes as they happen.")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .onSurface()

                Section {
                    if members.isEmpty {
                        MemberRow(name: String(localized: "You"), status: String(localized: "Owner"))
                    } else {
                        ForEach(members, id: \.self) { participant in
                            MemberRow(name: displayName(of: participant), status: status(of: participant))
                        }
                    }
                    Button {
                        Task { await openSharing() }
                    } label: {
                        HStack {
                            Label(share == nil ? "Invite People" : "Manage Members", systemImage: "person.crop.circle.badge.plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.forestInk)
                            if isPreparingShare {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isPreparingShare || persistence == nil)
                } header: {
                    SectionHeading(title: "Members").textCase(nil)
                } footer: {
                    Text("Invitations go through iCloud. Nobody needs an account with us.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .onSurface()

                Section {
                    Button { isEditingBudget = true } label: {
                        LabeledContent("Monthly Budget") {
                            Text(household.monthlyBudgetMinor > 0 ? Money.format(household.monthlyBudgetMinor) : String(localized: "None"))
                        }
                        .foregroundStyle(Color.ink)
                    }
                    Toggle("Start Shopping When I Arrive", isOn: Binding(
                        get: { noticesArrivals },
                        set: { enabled in Task { await StoreArrivalMonitor.shared.setEnabled(enabled) } }
                    ))
                    Toggle("Group Lists by Aisle", isOn: $groupsByAisle)
                } header: {
                    SectionHeading(title: "Settings").textCase(nil)
                }
                .tint(.forest)
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
                        .foregroundStyle(Color.forestInk)
                } header: {
                    SectionHeading(title: "Developer").textCase(nil)
                } footer: {
                    Text("Adds Aldi, Sainsbury’s, Tesco Express and Waitrose around Coulsdon with a fortnight of prices, and an example weekly list. Only in development builds.")
                        .foregroundStyle(Color.inkSecondary)
                }
                .onSurface()
                #endif
            }
            .themedList()
            .navigationTitle("Household")
            .sheet(isPresented: $isEditingBudget) {
                BudgetSheet(target: .month(household))
            }
            .sheet(isPresented: $isShowingHowItWorks) {
                HowItWorksSheet()
            }
            #if DEBUG
            .confirmationDialog("Load example data into “\(household.name ?? "")”?", isPresented: $isConfirmingExampleData, titleVisibility: .visible) {
                Button("Load Example Data") { ExampleData.load(into: household) }
            } message: {
                Text("It syncs to iCloud like anything else you add, including to anyone you share the household with.")
            }
            #endif
            .alert(
                "Couldn’t Share Household",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                name = household.name ?? ""
                share = persistence?.existingShare(for: household)
            }
            .onDisappear(perform: saveName)
        }
    }

    private func displayName(of participant: CKShare.Participant) -> String {
        if participant == share?.currentUserParticipant {
            return String(localized: "You")
        }
        if let components = participant.userIdentity.nameComponents {
            let formatted = components.formatted()
            if !formatted.isEmpty { return formatted }
        }
        return participant.userIdentity.lookupInfo?.emailAddress
            ?? participant.userIdentity.lookupInfo?.phoneNumber
            ?? String(localized: "Unknown")
    }

    private func status(of participant: CKShare.Participant) -> String {
        if participant.role == .owner { return String(localized: "Owner") }
        return participant.acceptanceStatus == .pending
            ? String(localized: "Invited")
            : String(localized: "Member")
    }

    private func saveName() {
        let trimmed = ProductName.display(name)
        guard isOwner, !trimmed.isEmpty, trimmed != household.name else { return }
        household.name = trimmed
        context.saveIfNeeded()
        if let share, let persistence {
            Task { try? await persistence.updateTitle(of: share, to: trimmed) }
        }
    }

    private func openSharing() async {
        guard let persistence else { return }
        saveName()
        isPreparingShare = true
        defer { isPreparingShare = false }

        let share: CKShare
        do {
            share = try await persistence.share(household)
        } catch {
            errorMessage = sharingErrorMessage(for: error)
            return
        }
        self.share = share

        let delegate = SharingDelegate(title: household.name) { stoppedShare in
            if household.isSharedWithMe {
                persistence.removeLocalCopy(of: stoppedShare)
            }
            self.share = persistence.existingShare(for: household)
        } onSave: {
            self.share = persistence.existingShare(for: household)
        }
        sharingDelegate = delegate

        let controller = UICloudSharingController(share: share, container: persistence.cloudKitContainer)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = delegate
        UIApplication.shared.topViewController?.present(controller, animated: true)
    }

    private func sharingErrorMessage(for error: any Error) -> String {
        if let ckError = error as? CKError, ckError.code == .notAuthenticated {
            return String(localized: "Sign in to iCloud in Settings to share your household.")
        }
        return error.localizedDescription
    }
}

private struct MemberRow: View {
    let name: String
    let status: String

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.subheadline.bold())
                .foregroundStyle(Color.forestInk)
                .frame(width: 40, height: 40)
                .background(Color.sagePale, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(name)
                    .foregroundStyle(Color.ink)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }
}

/// The licences of the icon sets the product icons come from.
private struct LicencesView: View {
    private var text: String {
        Bundle.main.url(forResource: "Icon Licences", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    var body: some View {
        ScrollView {
            Text(text)
                .font(.footnote.monospaced())
                .foregroundStyle(Color.ink)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .canvasBackground()
        .navigationTitle("Icon Licences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Receives events from Apple's sharing sheet, which holds its delegate weakly.
private final class SharingDelegate: NSObject, UICloudSharingControllerDelegate {
    private let title: String?
    private let onStop: (CKShare) -> Void
    private let onSave: () -> Void

    init(title: String?, onStop: @escaping (CKShare) -> Void, onSave: @escaping () -> Void) {
        self.title = title
        self.onStop = onStop
        self.onSave = onSave
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        title
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: any Error) {
        logger.error("Saving share failed: \(error)")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        onSave()
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        if let share = csc.share {
            onStop(share)
        }
    }
}
