import SwiftUI

/// The colours and symbols lists and shops can wear.
enum ListAppearance {
    static let colorNames = [
        "coral", "apricot", "amber", "olive", "sage", "teal",
        "sea", "slate", "indigo", "lavender", "orchid", "rose",
    ]

    /// Outlined, like the app's other icons. Lists saved with the filled
    /// versions are shown outlined by `outlined(_:)`.
    static let symbolNames = [
        "cart", "basket", "bag", "carrot", "fork.knife", "cup.and.saucer",
        "wineglass", "birthday.cake", "frying.pan", "flame", "leaf", "house",
        "gift", "pawprint", "stroller", "tshirt", "heart", "star",
    ]

    static func outlined(_ symbolName: String) -> String {
        symbolName.hasSuffix(".fill") ? String(symbolName.dropLast(5)) : symbolName
    }

    /// The swatch, exactly, in light and dark mode.
    static func color(named name: String?) -> Color {
        let rgb = swatch(named: name)
        return Color(light: rgb, dark: rgb)
    }

    /// White on the darker swatches, dark on the paler ones that can't carry white.
    static func foreground(named name: String?) -> Color {
        paleNames.contains(canonicalName(name)) ? Color(light: 0x15241B, dark: 0x15241B) : .white
    }

    static func title(named name: String?) -> String {
        canonicalName(name).capitalized
    }

    private static let paleNames: Set<String> = ["apricot", "amber", "olive", "sage", "teal", "sea", "orchid", "rose"]

    private static func swatch(named name: String?) -> UInt32 {
        switch canonicalName(name) {
        case "coral": 0xF15A3A
        case "apricot": 0xED9F6B
        case "amber": 0xEFAC40
        case "olive": 0x9DAD6C
        case "teal": 0x6FAD89
        case "sea": 0x79B5B0
        case "slate": 0x41738F
        case "indigo": 0x6573AD
        case "lavender": 0x8676B2
        case "orchid": 0xB58CC2
        case "rose": 0xCC8FAD
        default: 0x86AB81
        }
    }

    /// Lists and shops saved before these swatches used system colour names;
    /// each maps to the nearest new one. Unknown names become sage.
    private static func canonicalName(_ name: String?) -> String {
        switch name {
        case "red": "coral"
        case "orange": "apricot"
        case "yellow": "amber"
        case "brown": "olive"
        case "green": "sage"
        case "mint": "teal"
        case "cyan": "sea"
        case "blue": "slate"
        case "purple": "lavender"
        case "pink": "rose"
        case let name? where colorNames.contains(name): name
        default: "sage"
        }
    }
}
