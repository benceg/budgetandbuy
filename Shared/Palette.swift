import SwiftUI
import UIKit

/// A colour theme for the app, each matching one of the app icons. The brand
/// colours follow the chosen theme; the cream canvas, the green for money
/// saved and the apricot for warnings stay the same.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case sage, coral, slate, amber, lavender

    static let storageKey = "appTheme"

    /// The chosen theme. Sage unless someone picks another.
    static var current: AppTheme {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppTheme.init(rawValue:)) ?? .sage
    }

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .sage: "Sage"
        case .coral: "Coral"
        case .slate: "Slate"
        case .amber: "Amber"
        case .lavender: "Lavender"
        }
    }

    /// The swatch itself.
    var swatch: Color { Color(light: palette.soft, dark: palette.soft) }

    /// Shades taken from the matching app icon, with white text on `brand`
    /// and `brandInk` on cards both above 4.5:1 contrast.
    fileprivate var palette: ThemePalette {
        switch self {
        case .sage: ThemePalette(brand: (0x23503A, 0x3F7050), ink: (0x23503A, 0xB4D4B1), soft: 0x86AB81, pale: (0xD9E6D0, 0x193427))
        case .coral: ThemePalette(brand: (0x96251A, 0xC6452D), ink: (0x96251A, 0xFF8967), soft: 0xF15A3A, pale: (0xFBC4AF, 0x581C15))
        case .slate: ThemePalette(brand: (0x124667, 0x255F80), ink: (0x124667, 0x80ACC5), soft: 0x41738F, pale: (0xC2D4D9, 0x0F2F3F))
        case .amber: ThemePalette(brand: (0x79420D, 0xA46316), ink: (0x79420D, 0xFFDB86), soft: 0xEFAC40, pale: (0xFBE9BD, 0x482C0E))
        case .lavender: ThemePalette(brand: (0x41295F, 0x655083), ink: (0x41295F, 0xB8B1DF), soft: 0x8676B2, pale: (0xDBD6E5, 0x291F3B))
        }
    }
}

/// A theme's shades, each as light and dark RGB values.
private struct ThemePalette {
    let brand: (UInt32, UInt32)
    let ink: (UInt32, UInt32)
    let soft: UInt32
    let pale: (UInt32, UInt32)
}

/// The app's colours, each with a light and a dark value: the theme's colour
/// on warm cream by day, near-black by night, with apricot for anything that
/// needs attention.
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

    /// The theme colour for fills: buttons, selection, ticks.
    static let brand = Color(themed: { $0.brand })
    static let onBrand = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    /// The theme colour for text and icons, legible on cards and pale fills.
    static let brandInk = Color(themed: { $0.ink })
    static let brandSoft = Color(themed: { ($0.soft, $0.soft) })
    static let brandPale = Color(themed: { $0.pale })
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

    /// A colour that follows the chosen theme, read each time it's drawn.
    private init(themed shades: @escaping @Sendable (ThemePalette) -> (UInt32, UInt32)) {
        self.init(uiColor: UIColor { traits in
            let (light, dark) = shades(AppTheme.current.palette)
            return UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
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
