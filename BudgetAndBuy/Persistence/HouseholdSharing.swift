import CloudKit
import CoreData
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "Sharing")

/// Sharing a household shares everything that hangs off it: Core Data moves
/// the household and its related objects into a CloudKit share zone, and
/// objects added to it later follow it there.
extension PersistenceController {
    var cloudKitContainer: CKContainer {
        CKContainer(identifier: Self.cloudKitContainerIdentifier)
    }

    func existingShare(for household: Household) -> CKShare? {
        do {
            return try container.fetchShares(matching: [household.objectID])[household.objectID]
        } catch {
            logger.error("Fetching share failed: \(error)")
            return nil
        }
    }

    /// The household's share, created if it isn't shared yet.
    func share(_ household: Household) async throws -> CKShare {
        if let share = existingShare(for: household) { return share }

        let share: CKShare = try await withCheckedThrowingContinuation { continuation in
            container.share([household], to: nil) { _, share, _, error in
                if let share {
                    continuation.resume(returning: share)
                } else {
                    continuation.resume(throwing: error ?? CKError(.internalError))
                }
            }
        }
        try await updateTitle(of: share, to: household.name)
        return share
    }

    /// Keeps the name shown in invitations in step with the household's name.
    func updateTitle(of share: CKShare, to title: String?) async throws {
        guard let privateStore else { return }
        share[CKShare.SystemFieldKey.title] = title
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.persistUpdatedShare(share, in: privateStore) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func acceptShare(_ metadata: CKShare.Metadata) {
        guard let sharedStore else { return }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error {
                logger.error("Accepting share failed: \(error)")
            }
        }
    }

    /// Called after someone leaves a household that was shared with them.
    /// Their copy of its data goes; the owner's is untouched.
    func removeLocalCopy(of share: CKShare) {
        guard let sharedStore else { return }
        container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: sharedStore) { _, error in
            if let error {
                logger.error("Removing shared household failed: \(error)")
            }
        }
    }
}

extension PersistenceController {
    /// Deletes a household you own, for everyone it's shared with, or leaves
    /// one shared with you, keeping it for the others.
    func remove(_ household: Household) {
        guard let share = existingShare(for: household) else {
            viewContext.delete(household)
            viewContext.saveIfNeeded()
            return
        }
        if household.isSharedWithMe {
            removeLocalCopy(of: share)
        } else if let privateStore {
            // Purging the share's zone deletes the household and the share in iCloud.
            container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: privateStore) { _, error in
                if let error {
                    logger.error("Deleting shared household failed: \(error)")
                }
            }
        }
    }
}

extension Household {
    /// True for a household someone else owns and has shared with you.
    var isSharedWithMe: Bool {
        PersistenceController.isSharedStore(objectID.persistentStore)
    }
}
