import ActivityKit
import Foundation

/// The Live Activity shown while shopping. The app starts and updates it; the
/// widget extension draws it on the Lock Screen and in the Dynamic Island.
struct ShoppingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var basketMinor: Int64
        var basketCount: Int
        var remainingCount: Int
        /// The next few things to pick up, in aisle order.
        var upNext: [String]
    }

    var listID: String
    var listName: String
    var storeName: String
    var colorName: String
}
