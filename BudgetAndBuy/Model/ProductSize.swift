import Foundation

/// A pack size such as 2 L, 4 pints or 500 g. Products with the same name but
/// different sizes are different products, so their prices compare like for like.
struct ProductSize: Hashable {
    /// Raw values are stored on Product, so never change one once it has shipped.
    enum Unit: String, CaseIterable, Identifiable {
        case grams = "g"
        case kilograms = "kg"
        case millilitres = "ml"
        case litres = "l"
        case pints = "pt"
        case pack = "pack"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .grams: "g"
            case .kilograms: "kg"
            case .millilitres: "ml"
            case .litres: "L"
            case .pints: "pt"
            case .pack: String(localized: "pack")
            }
        }

        var title: LocalizedStringResource {
            switch self {
            case .grams: "Grams"
            case .kilograms: "Kilograms"
            case .millilitres: "Millilitres"
            case .litres: "Litres"
            case .pints: "Pints"
            case .pack: "Pack"
            }
        }

        /// How many of the unit-price unit (kg, L or item) one of these is.
        /// Pints are imperial: 568 ml.
        fileprivate var perBaseUnit: Double {
            switch self {
            case .grams, .millilitres: 0.001
            case .kilograms, .litres, .pack: 1
            case .pints: 0.568_261
            }
        }

        /// The unit shelf labels price by.
        fileprivate var baseSymbol: String {
            switch self {
            case .grams, .kilograms: "kg"
            case .millilitres, .litres, .pints: "L"
            case .pack: String(localized: "item")
            }
        }
    }

    var amount: Double
    var unit: Unit

    init?(amount: Double, unit: Unit?) {
        guard amount > 0, let unit else { return nil }
        self.amount = amount
        self.unit = unit
    }

    /// "2 L", "4 pt", "500 g", "6 pack".
    var formatted: String {
        "\(amount.formatted(.number.precision(.fractionLength(0...2)))) \(unit.symbol)"
    }

    /// Price per kg, litre or item, e.g. "£0.73/L".
    func unitPrice(of amountMinor: Int64) -> String {
        let perBase = Double(amountMinor) / (amount * unit.perBaseUnit)
        return "\(Money.format(Int64(perBase.rounded())))/\(unit.baseSymbol)"
    }

    private static let unitWords: [String: Unit] = [
        "g": .grams, "gram": .grams, "grams": .grams,
        "kg": .kilograms, "kilo": .kilograms, "kilos": .kilograms,
        "ml": .millilitres,
        "l": .litres, "ltr": .litres, "litre": .litres, "litres": .litres, "liter": .litres, "liters": .litres,
        "pt": .pints, "pint": .pints, "pints": .pints,
        "pk": .pack, "pack": .pack,
    ]

    private static let sizePattern = #"(\d+(?:[.,]\d+)?)\s*([a-z]+)"#

    /// Splits a size off either end of what someone typed:
    /// "Milk 2L" and "4 pints semi-skimmed milk" both work.
    static func split(_ text: String) -> (name: String, size: ProductSize?) {
        let text = ProductName.display(text)
        // Built per call: Regex isn't Sendable, so it can't be a shared static.
        let trailing = try! Regex(#"^(.+?)\s+"# + sizePattern + "$").ignoresCase()
        let leading = try! Regex("^" + sizePattern + #"\s+(.+)$"#).ignoresCase()
        if let match = try? trailing.wholeMatch(in: text),
           let size = size(amount: match.output[2].substring, unit: match.output[3].substring),
           let name = match.output[1].substring {
            return (String(name), size)
        }
        if let match = try? leading.wholeMatch(in: text),
           let size = size(amount: match.output[1].substring, unit: match.output[2].substring),
           let name = match.output[3].substring {
            return (String(name), size)
        }
        return (text, nil)
    }

    private static func size(amount: Substring?, unit: Substring?) -> ProductSize? {
        guard let amount, let unit, let unitValue = unitWords[unit.lowercased()],
              let value = Double(amount.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return ProductSize(amount: value, unit: unitValue)
    }
}

extension Product {
    var size: ProductSize? {
        get { ProductSize(amount: sizeAmount, unit: sizeUnit.flatMap(ProductSize.Unit.init(rawValue:))) }
        set {
            sizeAmount = newValue?.amount ?? 0
            sizeUnit = newValue?.unit.rawValue
        }
    }

    /// The name with its size, e.g. "Milk 2 L".
    var title: String {
        [name, size?.formatted].compactMap(\.self).joined(separator: " ")
    }

    /// Products match when both name and size match.
    func matches(normalizedName key: String, size: ProductSize?) -> Bool {
        normalizedName == key && self.size == size
    }

    var identityKey: String {
        "\(normalizedName ?? "")|\(size.map { "\($0.amount)\($0.unit.rawValue)" } ?? "")"
    }
}
