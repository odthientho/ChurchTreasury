import Foundation

/// The structured result of reading a photographed weekly-contribution paper
/// form. Everything here is a best-effort OCR guess — the import flow always
/// shows it on an editable review screen before anything is saved.
struct ParsedWeeklyReport: Sendable, Equatable {
    struct Contribution: Sendable, Equatable {
        var name: String
        var checkAmountCents: Int?
        var checkNumber: String?
        var cashAmountCents: Int?
    }
    struct Expense: Sendable, Equatable {
        var paidTo: String
        var note: String
        var amountCents: Int
    }
    var date: Date?
    var contributions: [Contribution] = []
    /// Loose-cash bill counts read from the CASH INCOME table, keyed by
    /// denomination (1, 2, 5, 10, 20, 50, 100).
    var denominationCounts: [Int: Int] = [:]
    var expenses: [Expense] = []
    var warnings: [String] = []
}

/// Reconstructs the paper form's tables from positioned OCR text. Pure
/// Foundation so the column/row logic is unit-testable with synthetic line
/// layouts, exactly like `CheckOCRParser`. Vision bounding boxes are
/// normalized with origin at bottom-left, so a *larger* `minY` is *higher* on
/// the page.
struct WeeklyReportImportParser: Sendable {

    /// US bill denominations, matching the CASH INCOME table order.
    static let billValues = [1, 2, 5, 10, 20, 50, 100]

    /// Tokens closer than this (normalized) vertical distance are treated as
    /// the same table row.
    private let rowTolerance: CGFloat = 0.012

    private static var moneyPattern: Regex<(Substring, Substring)> {
        /\$?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)/
    }
    private static var datePattern: Regex<Substring> {
        /\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}\b/
    }

    func parse(lines: [RecognizedTextLine]) -> ParsedWeeklyReport {
        var result = ParsedWeeklyReport()
        result.date = extractDate(lines)

        let anchors = Anchors(lines: lines)
        result.contributions = parseContributions(lines, anchors)
        result.denominationCounts = parseDenominations(lines, anchors)
        result.expenses = parseExpenses(lines, anchors)

        if result.contributions.isEmpty && result.expenses.isEmpty
            && result.denominationCounts.isEmpty {
            result.warnings.append(String(localized: "import.warning.nothingFound"))
        }
        return result
    }

    // MARK: - Anchors (printed headers on the template)

    /// Column reference points found from the form's printed labels, with
    /// fractional fallbacks for when a header isn't recognized.
    private struct Anchors {
        var headerY: CGFloat = 0.9      // below this y = contribution rows
        var splitX: CGFloat = 0.5       // left of this = contribution list
        var nameStartX: CGFloat = 0.08
        var checkAmountX: CGFloat = 0.34
        var checkNumberX: CGFloat = 0.42
        var cashX: CGFloat = 0.5

        var expenseTopY: CGFloat = 0.6  // below this (on the right) = expenses
        var expenseBottomY: CGFloat = 0.15
        var paidToX: CGFloat = 0.6
        var descriptionX: CGFloat = 0.75
        var expenseAmountX: CGFloat = 0.92

        init(lines: [RecognizedTextLine]) {
            func find(_ predicate: (String) -> Bool) -> RecognizedTextLine? {
                lines.first { predicate($0.text.uppercased().trimmingCharacters(in: .whitespaces)) }
            }

            if let name = find({ $0 == "NAME" }) {
                headerY = name.boundingBox.minY - 0.004
                nameStartX = name.boundingBox.minX
            }
            // The contribution list's own "CASH" header (exact match — avoids
            // "CASH INCOME"/"CASH EXPENSE") sits in the left half.
            if let cash = lines.first(where: {
                $0.text.uppercased().trimmingCharacters(in: .whitespaces) == "CASH"
                    && $0.boundingBox.midX < 0.6
            }) {
                cashX = cash.boundingBox.midX
                splitX = cash.boundingBox.maxX + 0.04
            }
            if let ch = find({ $0.replacingOccurrences(of: " ", with: "") == "CH#" }) {
                checkNumberX = ch.boundingBox.midX
            }
            // Left-half "Amount" headers: leftmost is the check amount column.
            let leftAmounts = lines
                .filter { $0.text.uppercased().contains("AMOUNT") && $0.boundingBox.midX < splitX }
                .sorted { $0.boundingBox.midX < $1.boundingBox.midX }
            if let checkAmount = leftAmounts.first {
                checkAmountX = checkAmount.boundingBox.midX
            }

            if let expense = find({ $0.contains("CASH EXPENSE") || $0 == "EXPENSE" }) {
                expenseTopY = expense.boundingBox.minY - 0.004
            }
            if let verified = find({ $0.contains("VERIFIED") }) {
                expenseBottomY = verified.boundingBox.maxY
            }
            if let paidTo = find({ $0.contains("PAID TO") }) {
                paidToX = paidTo.boundingBox.midX
                expenseTopY = min(expenseTopY, paidTo.boundingBox.minY - 0.004)
            }
            if let description = find({ $0.contains("DESCRIPTION") }) {
                descriptionX = description.boundingBox.midX
            }
        }
    }

    // MARK: - Contribution list

    private func parseContributions(_ lines: [RecognizedTextLine], _ a: Anchors) -> [ParsedWeeklyReport.Contribution] {
        let rowLines = lines.filter {
            $0.boundingBox.midX < a.splitX
                && $0.boundingBox.minY < a.headerY
                && $0.boundingBox.minY > 0.03
        }
        var result: [ParsedWeeklyReport.Contribution] = []
        for row in cluster(rowLines) {
            var name = ""
            // Numbers written on the check side of the row (offering amount +
            // check number), kept in left-to-right order. On the paper form
            // the FIRST of these columns is always the offering amount and the
            // SECOND is the check number — so assign them by position rather
            // than trying to tell two short numbers apart from OCR'd headers,
            // which swapped them. Only the cash column is still located by
            // header, since it's a genuinely separate column further right.
            var checkColumnNumbers: [(x: CGFloat, text: String, cents: Int)] = []
            var cashAmount: Int?

            for token in row.sorted(by: { $0.boundingBox.minX < $1.boundingBox.minX }) {
                let text = token.text.trimmingCharacters(in: .whitespaces)
                let x = token.boundingBox.midX
                if let cents = money(text) {
                    // Ignore the printed row number in the far-left "#" column.
                    if x < a.nameStartX - 0.01 { continue }
                    if nearest(x, to: [(a.checkAmountX, 0), (a.checkNumberX, 1), (a.cashX, 2)]) == 2 {
                        cashAmount = cents
                    } else {
                        checkColumnNumbers.append((x, text, cents))
                    }
                } else if text.contains(where: { $0.isLetter }) {
                    name = name.isEmpty ? text : name + " " + text
                }
            }

            checkColumnNumbers.sort { $0.x < $1.x }
            let checkAmount = checkColumnNumbers.first?.cents
            let checkNumber = checkColumnNumbers.count >= 2 ? digits(checkColumnNumbers[1].text) : nil

            let cleanName = name.trimmingCharacters(in: .whitespaces)
            // Skip rows that captured only a name with no money.
            if checkAmount == nil && cashAmount == nil { continue }
            result.append(.init(name: cleanName, checkAmountCents: checkAmount,
                                checkNumber: checkNumber, cashAmountCents: cashAmount))
        }
        return result
    }

    // MARK: - Cash income denominations

    /// Reads the CASH INCOME table, which has three columns per row:
    /// **[dollar bill] [number of bills] [total]**. For each row the first
    /// column is the denomination ($1…$100) and the *second* column is the
    /// count — the third (total) is ignored. Assigning by column order avoids
    /// mistaking a count or total that happens to equal a bill value (e.g. a
    /// count of "20", or a "$50" total) for a denomination.
    private func parseDenominations(_ lines: [RecognizedTextLine], _ a: Anchors) -> [Int: Int] {
        // Bound the table: right half, below the "CASH INCOME" header (if seen)
        // and above the cash-expense table, so income-summary numbers elsewhere
        // on the page don't leak in.
        let headerY = lines.first {
            $0.text.uppercased().contains("CASH INCOME")
        }?.boundingBox.minY
        let tableLines = lines.filter {
            $0.boundingBox.midX > a.splitX
                && $0.boundingBox.minY > a.expenseTopY
                && $0.boundingBox.minY < (headerY.map { $0 - 0.004 } ?? 1.0)
        }

        var counts: [Int: Int] = [:]
        for row in cluster(tableLines) {
            var denomination: Int?
            var count: Int?
            for token in row.sorted(by: { $0.boundingBox.minX < $1.boundingBox.minX }) {
                guard let n = Int(digits(token.text)), n > 0 else { continue }
                if denomination == nil {
                    // First column must be a real bill value, else this row is
                    // a header/label line — skip it.
                    if Self.billValues.contains(n) { denomination = n } else { break }
                } else if count == nil {
                    count = n              // second column = number of bills
                    break                  // ignore the third (total) column
                }
            }
            if let denomination, let count { counts[denomination] = count }
        }
        return counts
    }

    // MARK: - Cash expenses

    private func parseExpenses(_ lines: [RecognizedTextLine], _ a: Anchors) -> [ParsedWeeklyReport.Expense] {
        let rowLines = lines.filter {
            $0.boundingBox.midX > a.splitX
                && $0.boundingBox.minY < a.expenseTopY
                && $0.boundingBox.minY > a.expenseBottomY
        }
        var result: [ParsedWeeklyReport.Expense] = []
        for row in cluster(rowLines) {
            var paidTo = ""
            var note = ""
            var amount: Int?
            for token in row.sorted(by: { $0.boundingBox.minX < $1.boundingBox.minX }) {
                let text = token.text.trimmingCharacters(in: .whitespaces)
                let x = token.boundingBox.midX
                if let cents = money(text), x > (a.descriptionX + a.expenseAmountX) / 2 {
                    amount = cents
                } else if !text.isEmpty {
                    if x < (a.paidToX + a.descriptionX) / 2 {
                        paidTo = paidTo.isEmpty ? text : paidTo + " " + text
                    } else {
                        note = note.isEmpty ? text : note + " " + text
                    }
                }
            }
            guard let amount, amount > 0 else { continue }
            result.append(.init(paidTo: paidTo.trimmingCharacters(in: .whitespaces),
                                note: note.trimmingCharacters(in: .whitespaces),
                                amountCents: amount))
        }
        return result
    }

    // MARK: - Helpers

    /// Groups tokens into rows by vertical proximity, top of page first.
    private func cluster(_ lines: [RecognizedTextLine]) -> [[RecognizedTextLine]] {
        let sorted = lines.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        var rows: [[RecognizedTextLine]] = []
        for line in sorted {
            if let index = rows.firstIndex(where: {
                abs(($0.first?.boundingBox.minY ?? 0) - line.boundingBox.minY) < rowTolerance
            }) {
                rows[index].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows
    }

    private func money(_ text: String) -> Int? {
        guard let match = text.firstMatch(of: Self.moneyPattern) else { return nil }
        // Guard against matching only part of a longer word/label.
        guard let cents = Money.parseCents(String(match.1)), cents > 0 else { return nil }
        return cents
    }

    private func digits(_ text: String) -> String {
        text.filter(\.isNumber)
    }

    private func nearest(_ x: CGFloat, to columns: [(CGFloat, Int)]) -> Int {
        columns.min { abs($0.0 - x) < abs($1.0 - x) }?.1 ?? 0
    }

    private func extractDate(_ lines: [RecognizedTextLine]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Non-lenient so a malformed match is rejected rather than coerced.
        formatter.isLenient = false
        for line in lines {
            guard let match = line.text.firstMatch(of: Self.datePattern) else { continue }
            let text = String(line.text[match.range])
            // Pick the year format from the *actual* number of year digits.
            // DateFormatter's "yyyy" leniently accepts a 2-digit token and
            // reads "26" as year 0026, so a handwritten "6/29/25" would parse
            // to the year 25 A.D. — choose "yy" (→ 2025) vs "yyyy" explicitly.
            let separator: Character = text.contains("/") ? "/" : "-"
            let parts = text.split(separator: separator)
            guard parts.count == 3 else { continue }
            let sep = String(separator)
            let yearFormat = parts[2].count >= 4 ? "yyyy" : "yy"
            formatter.dateFormat = "M\(sep)d\(sep)\(yearFormat)"
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
