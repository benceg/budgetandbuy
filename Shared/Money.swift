import Foundation

/// Prices are stored as whole minor units (pence) so sums are exact.
enum Money {
    static var currencyCode: String { Locale.current.currency?.identifier ?? "GBP" }
    static var currencySymbol: String { Locale.current.currencySymbol ?? "£" }

    static func format(_ minorUnits: Int64) -> String {
        (Decimal(minorUnits) / 100).formatted(.currency(code: currencyCode))
    }

    /// The amount as you'd type it, without the currency symbol: 115 → "1.15".
    static func editableText(_ minorUnits: Int64) -> String {
        (Decimal(minorUnits) / 100).formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }

    /// Parses what someone typed into a price field. Nil for anything that isn't
    /// a non-negative amount.
    static func minorUnits(from text: String, locale: Locale = .current) -> Int64? {
        let separator = locale.decimalSeparator ?? "."
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: separator, with: ".")
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned), value >= 0 else { return nil }
        var unrounded = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &unrounded, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}
