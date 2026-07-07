import Foundation

/// Parses the text of a Chase checking statement (extracted via PDFKit) into
/// transactions. Pure Foundation so it is unit-testable; anything it cannot
/// parse becomes a warning surfaced in the review screen — the import flow
/// never trusts this output without user confirmation.
struct ChaseStatementParser: Sendable {

    struct ParsedTransaction: Equatable, Sendable {
        var date: Date
        var description: String
        var amountCents: Int
        var section: StatementSection
        var checkNumber: String?
    }

    struct Result: Sendable {
        var periodStart: Date?
        var periodEnd: Date?
        var beginningCents: Int?
        var endingCents: Int?
        var transactions: [ParsedTransaction] = []
        var warnings: [String] = []
    }

    private static let sectionHeaders: [(prefix: String, section: StatementSection)] = [
        ("DEPOSITS AND ADDITIONS", .deposit),
        ("CHECKS PAID", .checkPaid),
        ("ATM & DEBIT CARD WITHDRAWALS", .atmDebit),
        ("ATM AND DEBIT CARD WITHDRAWALS", .atmDebit),
        ("ELECTRONIC WITHDRAWALS", .electronic),
        ("FEES AND OTHER WITHDRAWALS", .fee),
        ("FEES", .fee),
        ("OTHER WITHDRAWALS", .fee),
    ]

    // Regex isn't Sendable, so these are computed rather than stored statics.
    // "12/07  Deposit 1234567890  2,432.10" with an optional trailing balance column
    private static var generalLine: Regex<(Substring, Substring, Substring, Substring)> {
        /^(\d{2}\/\d{2})\s+(.+?)\s+\$?(-?[\d,]+\.\d{2})(?:\s+\$?-?[\d,]+\.\d{2})?$/
    }

    // "1101 ^ 12/10 $700.00" — check number leads, optional ^ or * marker
    private static var checkLine: Regex<(Substring, Substring, Substring, Substring)> {
        /^(\d{2,6})\s*[\^\*]?\s*(\d{2}\/\d{2})\s+\$?([\d,]+\.\d{2})$/
    }

    private static var periodPattern: Regex<(Substring, Substring, Substring)> {
        /([A-Z][a-z]+ \d{1,2}, \d{4})\s*through\s*([A-Z][a-z]+ \d{1,2}, \d{4})/
    }

    private static var beginningPattern: Regex<(Substring, Substring)> {
        /Beginning Balance\s*\$?(-?[\d,]+\.\d{2})/
    }

    private static var endingPattern: Regex<(Substring, Substring)> {
        /Ending Balance\s*\$?(-?[\d,]+\.\d{2})/
    }

    // Column headers and totals we silently skip inside a section
    private static let noisePrefixes = [
        "DATE", "CHECK NO", "DESCRIPTION", "AMOUNT", "TOTAL",
    ]

    // PDF extraction sometimes merges several printed rows into one line.
    // A boundary is an amount followed by the start of a new row: a MM/dd
    // date, a check-number-then-date, or a "Total ..." footer.
    private static var mergedRowBoundary: Regex<(Substring, Substring)> {
        /(-?[\d,]+\.\d{2})\s+(?=\d{2}\/\d{2}\s|\d{2,6}\s*[\^\*]?\s*\d{2}\/\d{2}\s|Total\s)/
    }

    func parse(text: String) -> Result {
        var result = Result()

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result.warnings.append(String(localized: "parser.warning.emptyText"))
            return result
        }

        parseHeader(text: text, into: &result)

        var currentSection: StatementSection?
        let lines = text.components(separatedBy: .newlines)
            .flatMap { $0.replacing(Self.mergedRowBoundary) { "\($0.output.1)\n" }
                .components(separatedBy: "\n") }
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let upper = line.uppercased()

            if let header = Self.sectionHeaders.first(where: { upper.hasPrefix($0.prefix) }) {
                // Header line, possibly "(continued)"; a summary-table line like
                // "Deposits and Additions 5,432.10" also lands here harmlessly —
                // no transaction rows follow until the real section starts.
                currentSection = header.section
                continue
            }

            guard let section = currentSection else { continue }

            if upper.hasPrefix("TOTAL") {
                currentSection = nil
                continue
            }
            if Self.noisePrefixes.contains(where: { upper.hasPrefix($0) }) {
                continue
            }

            if let txn = parseTransactionLine(line, section: section, result: result) {
                result.transactions.append(txn)
            } else if line.contains(/\d{2}\/\d{2}/) {
                result.warnings.append(
                    String(localized: "parser.warning.unparsedLine \(line)")
                )
            }
        }

        crossCheckTotals(&result)
        return result
    }

    // MARK: - Header

    private func parseHeader(text: String, into result: inout Result) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"

        if let match = text.firstMatch(of: Self.periodPattern) {
            result.periodStart = formatter.date(from: String(match.1))
            result.periodEnd = formatter.date(from: String(match.2))
        } else {
            result.warnings.append(String(localized: "parser.warning.noPeriod"))
        }

        if let match = text.firstMatch(of: Self.beginningPattern) {
            result.beginningCents = Money.parseCents(String(match.1))
        }
        if let match = text.firstMatch(of: Self.endingPattern) {
            result.endingCents = Money.parseCents(String(match.1))
        }
    }

    // MARK: - Lines

    private func parseTransactionLine(_ line: String, section: StatementSection,
                                      result: Result) -> ParsedTransaction? {
        if section == .checkPaid, let match = line.firstMatch(of: Self.checkLine) {
            guard let cents = Money.parseCents(String(match.3)),
                  let date = resolveDate(monthDay: String(match.2), result: result)
            else { return nil }
            return ParsedTransaction(
                date: date,
                description: String(localized: "parser.checkDescription \(String(match.1))"),
                amountCents: cents,
                section: section,
                checkNumber: String(match.1)
            )
        }

        if let match = line.firstMatch(of: Self.generalLine) {
            guard let cents = Money.parseCents(String(match.3)),
                  let date = resolveDate(monthDay: String(match.1), result: result)
            else { return nil }
            var description = String(match.2).trimmingCharacters(in: .whitespaces)
            var checkNumber: String?
            if section == .checkPaid,
               let checkMatch = description.firstMatch(of: /^(\d{2,6})\b\s*[\^\*]?\s*/) {
                checkNumber = String(checkMatch.1)
                description = String(description[checkMatch.range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if description.isEmpty {
                    description = String(localized: "parser.checkDescription \(String(checkMatch.1))")
                }
            }
            return ParsedTransaction(
                date: date,
                description: description,
                amountCents: abs(cents),
                section: section,
                checkNumber: checkNumber
            )
        }

        return nil
    }

    /// Resolves "MM/dd" to a full date using the statement period's year(s),
    /// handling statements that span a year boundary (Dec -> Jan).
    private func resolveDate(monthDay: String, result: Result) -> Date? {
        let parts = monthDay.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]), let day = Int(parts[1]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")

        var candidateYears: [Int] = []
        if let start = result.periodStart {
            candidateYears.append(calendar.component(.year, from: start))
        }
        if let end = result.periodEnd {
            let year = calendar.component(.year, from: end)
            if !candidateYears.contains(year) { candidateYears.append(year) }
        }
        if candidateYears.isEmpty {
            candidateYears = [calendar.component(.year, from: Date())]
        }

        let slack: TimeInterval = 5 * 24 * 3600
        var fallback: Date?
        for year in candidateYears {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
            else { continue }
            fallback = fallback ?? date
            if let start = result.periodStart, let end = result.periodEnd {
                if date >= start.addingTimeInterval(-slack), date <= end.addingTimeInterval(slack) {
                    return date
                }
            } else {
                return date
            }
        }
        return fallback
    }

    // MARK: - Validation

    /// Verifies beginning + deposits − withdrawals == ending; a mismatch means
    /// lines were missed or misparsed, so surface it prominently.
    private func crossCheckTotals(_ result: inout Result) {
        guard let beginning = result.beginningCents, let ending = result.endingCents else {
            result.warnings.append(String(localized: "parser.warning.noBalances"))
            return
        }
        let deposits = result.transactions
            .filter { $0.section == .deposit }
            .reduce(0) { $0 + $1.amountCents }
        let withdrawals = result.transactions
            .filter { $0.section.isWithdrawal }
            .reduce(0) { $0 + $1.amountCents }
        let computed = beginning + deposits - withdrawals
        if computed != ending {
            result.warnings.append(String(
                localized: "parser.warning.totalsMismatch \(Money.format(computed)) \(Money.format(ending))"
            ))
        }
    }
}
