import SwiftUI

/// The colours and symbols a list can wear, as in Reminders.
enum ListAppearance {
    static let colorNames = [
        "red", "orange", "yellow", "green", "mint", "teal",
        "cyan", "blue", "indigo", "purple", "pink", "brown",
    ]

    static let symbolNames = [
        "cart.fill", "basket.fill", "bag.fill", "carrot.fill", "fork.knife", "cup.and.saucer.fill",
        "wineglass.fill", "birthday.cake.fill", "frying.pan.fill", "flame.fill", "leaf.fill", "house.fill",
        "gift.fill", "pawprint.fill", "stroller.fill", "tshirt.fill", "heart.fill", "star.fill",
    ]

    /// Colours tuned to sit with the app's greens and cream.
    static func color(named name: String?) -> Color {
        switch name {
        case "red": Color(light: 0xD9473A, dark: 0xE8604F)
        case "orange": Color(light: 0xEE8A3C, dark: 0xF39A50)
        case "yellow": Color(light: 0xD9A520, dark: 0xE6B53A)
        case "mint": Color(light: 0x3FA889, dark: 0x5CC2A2)
        case "teal": Color(light: 0x2F8A8A, dark: 0x45A7A5)
        case "cyan": Color(light: 0x2E9CC6, dark: 0x4CB3DA)
        case "blue": Color(light: 0x3569C9, dark: 0x5585E0)
        case "indigo": Color(light: 0x4F4CB8, dark: 0x6E6BD6)
        case "purple": Color(light: 0x8A4DB5, dark: 0xA46ACC)
        case "pink": Color(light: 0xD3507F, dark: 0xE46D97)
        case "brown": Color(light: 0x8E6A48, dark: 0xA88463)
        default: Color(light: 0x2C7A4B, dark: 0x4E9B6B)
        }
    }
}
