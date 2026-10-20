import SwiftUI
import UIKit

/// The app's colours, each with a light and a dark value: forest greens and
/// sage on warm cream by day, deep green-black by night, with apricot for
/// anything that needs attention.
extension Color {
    /// The page behind everything.
    static let canvas = Color(light: 0xF8F4EA, dark: 0x0C120F)
    /// Cards and rows.
    static let surface = Color(light: 0xFFFDF8, dark: 0x161F1A)
    /// Fields, idle chips and tracks.
    static let sunken = Color(light: 0xEFE8D8, dark: 0x222D27)
    static let hairline = Color(light: 0xE3DCCB, dark: 0x2B3631)

    static let ink = Color(light: 0x15241B, dark: 0xEDF1EA)
    static let inkSecondary = Color(light: 0x5F6B63, dark: 0x9AA79F)

    /// The brand colour: buttons, selection, ticks.
    static let forest = Color(light: 0x1E4B34, dark: 0x3C7652)
    static let onForest = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    /// Green for text and icons, legible on cards and pale fills in both modes.
    static let forestInk = Color(light: 0x1E4B34, dark: 0x8BCAA1)
    static let sage = Color(light: 0x8FAE98, dark: 0x7E9886)
    static let sagePale = Color(light: 0xDCE6D7, dark: 0x22362A)
    /// Money saved and carbon avoided.
    static let leaf = Color(light: 0x2C7A4B, dark: 0x7CC196)
    /// Over budget, extra cost, things to look at.
    static let apricot = Color(light: 0xE0773B, dark: 0xF0803F)
    static let apricotPale = Color(light: 0xFCE5D4, dark: 0x3A2618)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
