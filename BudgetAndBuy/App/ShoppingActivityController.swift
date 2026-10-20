import ActivityKit
import os

private let logger = Logger(subsystem: "app.budgetandbuy", category: "LiveActivity")

/// Keeps one shopping Live Activity running while you shop, for the list
/// you're shopping from.
@MainActor
final class ShoppingActivityController {
    static let shared = ShoppingActivityController()

    private var pending: Task<Void, Never>?

    /// Starts, updates or (with a nil state) ends the activity for a list.
    func sync(_ attributes: ShoppingActivityAttributes, state: ShoppingActivityAttributes.ContentState?) {
        // Applied in order, so quick successive changes can't start two activities.
        let previous = pending
        pending = Task {
            await previous?.value
            await Self.apply(attributes, state: state)
        }
    }

    // Looks activities up itself rather than receiving them, because
    // Activity can't be passed between isolation domains.
    private nonisolated static func apply(
        _ attributes: ShoppingActivityAttributes,
        state: ShoppingActivityAttributes.ContentState?
    ) async {
        var current: Activity<ShoppingActivityAttributes>?
        for activity in Activity<ShoppingActivityAttributes>.activities {
            let isThisShop = activity.attributes.listID == attributes.listID
                && activity.attributes.storeName == attributes.storeName
            if isThisShop, state != nil, current == nil {
                current = activity
            } else if state != nil || activity.attributes.listID == attributes.listID {
                // Only one shop at a time: anything else running is stale.
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        guard let state else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        if let current {
            await current.update(content)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: attributes, content: content)
            } catch {
                logger.error("Starting the Live Activity failed: \(error)")
            }
        }
    }
}
