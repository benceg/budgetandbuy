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
    var swatch: Color { Color(light: palette.swatch, dark: palette.swatch) }

    /// Fills and themed text use the swatch exactly; at night Slate and
    /// Lavender text are lightened a little to show on the dark cards. Text on
    /// a fill is white or dark, whichever reads better.
    fileprivate var palette: ThemePalette {
        switch self {
        case .sage:
            ThemePalette(swatch: 0x86AB81, onSwatchIsDark: true, ink: (0x86AB81, 0x86AB81),
                         soft: (0xC6D6C2, 0x415441), pale: (0xE4EBDE, 0x354637))
        case .coral:
            ThemePalette(swatch: 0xF15A3A, onSwatchIsDark: false, ink: (0xF15A3A, 0xF15A3A),
                         soft: (0xF7A491, 0x5E3423), pale: (0xFCD9CE, 0x533023))
        case .slate:
            ThemePalette(swatch: 0x41738F, onSwatchIsDark: false, ink: (0x41738F, 0x618BA2),
                         soft: (0x8EAABA, 0x24404C), pale: (0xD5DFE1, 0x22373B))
        case .amber:
            ThemePalette(swatch: 0xEFAC40, onSwatchIsDark: true, ink: (0xEFAC40, 0xEFAC40),
                         soft: (0xF5CF8E, 0x5E4A23), pale: (0xFBEBD0, 0x534625))
        case .lavender:
            ThemePalette(swatch: 0x8676B2, onSwatchIsDark: false, ink: (0x8676B2, 0x8C7DB6),
                         soft: (0xB9AFD3, 0x3E3A52), pale: (0xE4DFE9, 0x353745))
        }
    }
}

/// A theme's shades as light and dark RGB values.
private struct ThemePalette {
    let swatch: UInt32
    /// Dark text on the swatch, for pale swatches that can't carry white.
    let onSwatchIsDark: Bool
    let ink: (UInt32, UInt32)
    let soft: (UInt32, UInt32)
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
    static let brand = Color(themed: { ($0.swatch, $0.swatch) })
    /// Text and icons on a `brand` fill.
    static let onBrand = Color(themed: { $0.onSwatchIsDark ? (0x15241B, 0x15241B) : (0xFFFFFF, 0xFFFFFF) })
    /// The theme colour for text, links and icons on cards.
    static let brandInk = Color(themed: { $0.ink })
    /// A lighter tint, for idle ticks, tracks and disabled buttons.
    static let brandSoft = Color(themed: { $0.soft })
    static let brandPale = Color(themed: { $0.pale })
    /// Money saved.
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
