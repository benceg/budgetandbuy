import CloudKit
import CoreData
import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Sharing")

/// One household's own settings: its name and colour, who's in it and how to
/// invite more people, its monthly budget, and deleting or leaving it.
struct HouseholdSettingsScreen: View {
    @ObservedObject var household: Household
    /// Whether it's the only household you have, which can't be deleted.
    let isOnlyHousehold: Bool
    @Environment(\.managedObjectContext) private var context
    @Environment(\.persistence) private var persistence
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorName = "sage"
    @State private var share: CKShare?
    @State private var isPreparingShare = false
    @State private var errorMessage: String?
    @State private var sharingDelegate: SharingDelegate?
    @State private var isEditingBudget = false
    @State private var isConfirmingRemoval = false

    private var isOwner: Bool { !household.isSharedWithMe }

    private var members: [CKShare.Participant] {
        (share?.participants ?? [])
            .filter { $0.acceptanceStatus != .removed }
            .sorted { ($0.role == .owner ? 0 : 1) < ($1.role == .owner ? 0 : 1) }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: "house")
                        .font(.system(size: 34))
                        .foregroundStyle(ListAppearance.foreground(named: colorName))
                        .frame(width: 84, height: 84)
                        .background(ListAppearance.color(named: colorName), in: .circle)
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

            if isOwner {
                Section {
                    SwatchGrid(items: ListAppearance.colorNames, selection: $colorName) { name in
                        Circle()
                            .fill(ListAppearance.color(named: name))
                            .accessibilityLabel(ListAppearance.title(named: name))
                    }
                } header: {
                    SectionHeading(title: "Colour").textCase(nil)
                }
                .onSurface()
            }

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
                            .foregroundStyle(Color.brandInk)
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
                Text("Invitations go through iCloud. Nobody needs an account with us, and other households you have stay private.")
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
            } header: {
                SectionHeading(title: "Budget").textCase(nil)
            }
            .onSurface()

            Section {
                Button(isOwner ? "Delete Household" : "Leave Household", role: .destructive) {
                    isConfirmingRemoval = true
                }
                .foregroundStyle(Color.apricot)
                .disabled(isOwner && isOnlyHousehold)
            } footer: {
                if isOwner && isOnlyHousehold {
                    Text("You need at least one household. Make another before deleting this one.")
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .onSurface()
        }
        .themedList()
        .navigationTitle(household.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingBudget) {
            BudgetSheet(target: .month(household))
        }
        .confirmationDialog(
            isOwner ? "Delete “\(household.name ?? "")”?" : "Leave “\(household.name ?? "")”?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button(isOwner ? "Delete Household" : "Leave Household", role: .destructive, action: remove)
        } message: {
            Text(removalMessage)
        }
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
            colorName = household.colorName ?? "sage"
            share = persistence?.existingShare(for: household)
        }
        .onChange(of: colorName) {
            guard isOwner, colorName != household.colorName else { return }
            household.colorName = colorName
            context.saveIfNeeded()
        }
        .onDisappear(perform: saveName)
    }

    private var removalMessage: LocalizedStringResource {
        if !isOwner {
            return "Its lists, shops and prices disappear from your devices. The others in it keep them."
        }
        return share == nil
            ? "Its lists, shops, prices and trips are deleted from all your devices. This can’t be undone."
            : "Its lists, shops, prices and trips are deleted for everyone it’s shared with. This can’t be undone."
    }

    private func remove() {
        guard let persistence else { return }
        dismiss()
        persistence.remove(household)
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
                .foregroundStyle(Color.brandInk)
                .frame(width: 40, height: 40)
                .background(Color.brandPale, in: .circle)
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
struct LicencesView: View {
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
