import Foundation

/// All amounts in the app are stored as integer cents so sums are exact and
/// always match the bank to the penny. Never route money through Double.
enum Money {
    /// Formats cents as localized USD currency, e.g. 123456 -> "$1,234.56".
    static func format(_ cents: Int) -> String {
        let decimal = Decimal(cents) / 100
        return decimal.formatted(.currency(code: "USD"))
    }

    /// Formats cents without the currency symbol, e.g. 123456 -> "1,234.56".
    static func formatPlain(_ cents: Int) -> String {
        let decimal = Decimal(cents) / 100
        return decimal.formatted(.number.precision(.fractionLength(2)))
    }

    /// Parses user/statement input like "1,234.56", "$1,234.56", "1234", ".5"
    /// into cents using pure string/integer math. Returns nil for invalid input.
    static func parseCents(_ input: String) -> Int? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        var negative = false
        if text.hasPrefix("-") {
            negative = true
            text.removeFirst()
        }
        if text.hasPrefix("(") && text.hasSuffix(")") {
            negative = true
            text = String(text.dropFirst().dropLast())
        }
        text = text.replacingOccurrences(of: "$", with: "")
        text = text.replacingOccurrences(of: ",", with: "")
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let wholePart = parts[0].isEmpty ? "0" : String(parts[0])
        guard let whole = Int(wholePart), whole >= 0 else { return nil }

        var fractionCents = 0
        if parts.count == 2 {
            var frac = String(parts[1])
            guard frac.count <= 2, frac.allSatisfy(\.isNumber) else { return nil }
            while frac.count < 2 { frac += "0" }
            fractionCents = Int(frac) ?? 0
        }

        let cents = whole * 100 + fractionCents
        return negative ? -cents : cents
    }
}
