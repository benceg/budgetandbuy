import CloudKit
import CoreData
import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Sharing")

/// The household's name and members, and the way into iCloud sharing.
struct HouseholdView: View {
    @ObservedObject var household: Household
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @Environment(\.persistence) private var persistence
    @State private var name = ""
    @State private var share: CKShare?
    @State private var isPreparingShare = false
    @State private var errorMessage: String?
    @State private var sharingDelegate: SharingDelegate?

    private var isOwner: Bool { !household.isSharedWithMe }

    private var members: [CKShare.Participant] {
        (share?.participants ?? [])
            .filter { $0.acceptanceStatus != .removed }
            .sorted { ($0.role == .owner ? 0 : 1) < ($1.role == .owner ? 0 : 1) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        ListIcon(symbolName: "house.fill", color: .accentColor, size: 80)
                        if isOwner {
                            TextField("Household Name", text: $name)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 12)
                                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
                                .submitLabel(.done)
                                .onSubmit(saveName)
                        } else {
                            Text(household.name ?? "")
                                .font(.title2.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Members") {
                    if members.isEmpty {
                        MemberRow(name: String(localized: "You"), status: String(localized: "Owner"))
                    } else {
                        ForEach(members, id: \.self) { participant in
                            MemberRow(
                                name: displayName(of: participant),
                                status: status(of: participant)
                            )
                        }
                    }
                }

                Section {
                    Button {
                        Task { await openSharing() }
                    } label: {
                        HStack {
                            Label(
                                share == nil ? "Share Household…" : "Manage Sharing…",
                                systemImage: "person.crop.circle.badge.plus"
                            )
                            if isPreparingShare {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isPreparingShare || persistence == nil)
                } footer: {
                    Text("Everyone in the household can see and edit all of its lists.")
                }
            }
            .navigationTitle("Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveName()
                        dismiss()
                    }
                }
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
                share = persistence?.existingShare(for: household)
            }
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(name)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
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

#Preview {
    let persistence = PersistenceController.preview
    HouseholdView(household: persistence.ensureHousehold())
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(\.persistence, persistence)
}
