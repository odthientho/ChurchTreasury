import Foundation

/// A recognized line of text and its position on the check. Bounding boxes
/// use Vision's normalized coordinate system: origin at bottom-left, values
/// 0...1, so a higher `minY` means closer to the top of a check laid
/// portrait or landscape as scanned.
struct RecognizedTextLine: Sendable, Equatable {
    var text: String
    var boundingBox: CGRect
}

struct ParsedCheck: Sendable, Equatable {
    var payerName: String?
    var amountCents: Int?
    var checkNumber: String?
    var checkDate: Date?
    var warnings: [String] = []
}

/// Heuristic field extraction from OCR'd check text. Pure Foundation so it is
/// unit-testable with synthetic line layouts — the same split used for the
/// bank statement parser: a thin Vision wrapper feeds this pure parser, and
/// nothing here is ever trusted without the user reviewing the result.
struct CheckOCRParser: Sendable {

    // Rightmost, most-money-looking amount wins: "$1,234.56" or "1234.56".
    private static var amountPattern: Regex<(Substring, Substring)> {
        /\$?\s?(\d{1,3}(?:,\d{3})*\.\d{2})/
    }

    // A short standalone number, typically the printed check number.
    private static var checkNumberPattern: Regex<(Substring, Substring)> {
        /^#?\s*(\d{3,6})\s*$/
    }

    private static var datePattern: Regex<Substring> {
        /\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}\b/
    }

    // Printed boilerplate that is never a payer's name.
    private static let nameBlocklist: Set<String> = [
        "PAY TO THE ORDER OF", "PAY TO THE", "ORDER OF", "DOLLARS", "MEMO",
        "DATE", "FOR", "VOID AFTER 90 DAYS", "VOID AFTER 180 DAYS",
    ]

    func parse(lines: [RecognizedTextLine]) -> ParsedCheck {
        var result = ParsedCheck()

        result.amountCents = extractAmount(lines: lines)
        if result.amountCents == nil {
            result.warnings.append(String(localized: "scan.warning.noAmount"))
        }

        result.checkNumber = extractCheckNumber(lines: lines)

        result.checkDate = extractDate(lines: lines)

        result.payerName = extractPayerName(lines: lines)
        if result.payerName == nil {
            result.warnings.append(String(localized: "scan.warning.noName"))
        }

        return result
    }

    /// The courtesy amount box sits in the upper-right portion of a check;
    /// among money-shaped matches, prefer the one furthest right and pick
    /// the one closest to the top among ties.
    private func extractAmount(lines: [RecognizedTextLine]) -> Int? {
        var best: (cents: Int, x: CGFloat, y: CGFloat)?
        for line in lines {
            guard let match = line.text.firstMatch(of: Self.amountPattern) else { continue }
            guard let cents = Money.parseCents(String(match.1)), cents > 0 else { continue }
            let x = line.boundingBox.minX
            let y = line.boundingBox.minY
            if best == nil || x > best!.x + 0.02 || (abs(x - best!.x) <= 0.02 && y > best!.y) {
                best = (cents, x, y)
            }
        }
        return best?.cents
    }

    /// The printed check number is a short standalone number in the top
    /// portion of the check (upper third), usually right-aligned.
    private func extractCheckNumber(lines: [RecognizedTextLine]) -> String? {
        let topLines = lines.filter { $0.boundingBox.minY > 0.6 }
        let candidates = topLines.compactMap { line -> (String, CGFloat)? in
            guard let match = line.text.firstMatch(of: Self.checkNumberPattern) else { return nil }
            return (String(match.1), line.boundingBox.minX)
        }
        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    private func extractDate(lines: [RecognizedTextLine]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for line in lines {
            guard let match = line.text.firstMatch(of: Self.datePattern) else { continue }
            let text = String(line.text[match.range])
            for format in ["M/d/yyyy", "M/d/yy", "M-d-yyyy", "M-d-yy"] {
                formatter.dateFormat = format
                if let date = formatter.date(from: text) {
                    return date
                }
            }
        }
        return nil
    }

    /// The account holder's printed name/address is the first substantial
    /// left-aligned line, scanning from the top, that isn't boilerplate,
    /// a date, or an amount.
    private func extractPayerName(lines: [RecognizedTextLine]) -> String? {
        let leftLines = lines
            .filter { $0.boundingBox.minX < 0.55 && $0.boundingBox.minY > 0.4 }
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        for line in leftLines {
            let text = line.text.trimmingCharacters(in: .whitespaces)
            guard text.count >= 3 else { continue }
            let upper = text.uppercased()
            if Self.nameBlocklist.contains(where: { upper.contains($0) }) { continue }
            if text.contains(/\d{2,}/) { continue }              // dates, numbers
            if text.firstMatch(of: Self.amountPattern) != nil { continue }
            if text.allSatisfy({ !$0.isLetter && !$0.isWhitespace }) { continue }
            return text
        }
        return nil
    }
}
