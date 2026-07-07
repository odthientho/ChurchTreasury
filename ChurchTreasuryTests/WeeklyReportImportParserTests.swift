import Foundation
import Testing
@testable import ChurchTreasury

/// The weekly-report OCR parser against synthetic positioned lines that stand
/// in for ideal OCR output (Vision normalized coords: origin bottom-left, so a
/// larger y is higher on the page).
struct WeeklyReportImportParserTests {

    private func line(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat = 0.06) -> RecognizedTextLine {
        RecognizedTextLine(text: text, boundingBox: CGRect(x: x, y: y, width: w, height: 0.02))
    }

    /// A minimal but complete form: headers, one check row, one envelope-cash
    /// row, a denomination count, and one cash expense.
    private func sampleLines() -> [RecognizedTextLine] {
        [
            // Contribution list headers (top band).
            line("NAME", x: 0.10, y: 0.90),
            line("CHECK", x: 0.34, y: 0.90),
            line("Amount", x: 0.32, y: 0.88),
            line("CH#", x: 0.42, y: 0.88),
            line("CASH", x: 0.50, y: 0.90),
            // A check row: name, amount in the check-amount column, check number.
            line("Hai Nguyen", x: 0.12, y: 0.82),
            line("80", x: 0.33, y: 0.82),
            line("143", x: 0.42, y: 0.82),
            // An envelope-cash row: name + amount in the cash column.
            line("Minh Tran", x: 0.12, y: 0.78),
            line("60", x: 0.50, y: 0.78),
            // CASH INCOME table (right half).
            line("CASH INCOME", x: 0.62, y: 0.70),
            line("$20", x: 0.60, y: 0.64),
            line("3", x: 0.70, y: 0.64),
            line("$60", x: 0.85, y: 0.64),
            // CASH EXPENSE table (right half, lower).
            line("CASH EXPENSE", x: 0.62, y: 0.50),
            line("Paid To", x: 0.62, y: 0.47),
            line("Description", x: 0.75, y: 0.47),
            line("Bay Tinh", x: 0.62, y: 0.43),
            line("Refund", x: 0.75, y: 0.43),
            line("79", x: 0.92, y: 0.43),
            line("Verified By", x: 0.62, y: 0.20),
        ]
    }

    @Test func parsesCheckAndEnvelopeContributions() {
        let parsed = WeeklyReportImportParser().parse(lines: sampleLines())

        #expect(parsed.contributions.count == 2)
        let check = parsed.contributions.first { $0.name == "Hai Nguyen" }
        #expect(check?.checkAmountCents == 8_000)
        #expect(check?.checkNumber == "143")
        #expect(check?.cashAmountCents == nil)

        let cash = parsed.contributions.first { $0.name == "Minh Tran" }
        #expect(cash?.cashAmountCents == 6_000)
        #expect(cash?.checkAmountCents == nil)
    }

    @Test func parsesDenominationCounts() {
        let parsed = WeeklyReportImportParser().parse(lines: sampleLines())
        #expect(parsed.denominationCounts[20] == 3)
    }

    @Test func denominationCountIsSecondColumnNotTotal() {
        // CASH INCOME rows are [dollar] [count] [total]. The count is the
        // middle column; the total must be ignored — and a count/total that
        // happens to equal a bill value must not create a phantom row.
        // Here: twenty $1 bills, total 20.
        let lines = [
            line("CASH INCOME", x: 0.62, y: 0.70),
            line("$1", x: 0.60, y: 0.64),   // denomination
            line("20", x: 0.72, y: 0.64),   // number of bills
            line("20", x: 0.86, y: 0.64),   // total — ignored
            line("CASH EXPENSE", x: 0.62, y: 0.30),
            line("Verified By", x: 0.62, y: 0.20),
        ]
        let parsed = WeeklyReportImportParser().parse(lines: lines)
        #expect(parsed.denominationCounts[1] == 20)
        #expect(parsed.denominationCounts[20] == nil)   // no phantom $20 row
    }

    @Test func parsesCashExpense() {
        let parsed = WeeklyReportImportParser().parse(lines: sampleLines())
        #expect(parsed.expenses.count == 1)
        #expect(parsed.expenses.first?.paidTo == "Bay Tinh")
        #expect(parsed.expenses.first?.amountCents == 7_900)
    }

    @Test func firstCheckColumnIsAmountSecondIsCheckNumber() {
        // Regression for the reported swap: even when the printed headers are
        // OCR'd in a confusing order (here "CH#" ends up left of "Amount"),
        // the paper form's fixed layout means the *left* number in the row is
        // the offering amount and the *right* number is the check number.
        let lines = [
            line("NAME", x: 0.10, y: 0.90),
            line("CH#", x: 0.30, y: 0.90),
            line("Amount", x: 0.44, y: 0.90),
            line("Ba Nguyen", x: 0.10, y: 0.80),
            line("250", x: 0.30, y: 0.80),   // physically first column → amount
            line("777", x: 0.44, y: 0.80),   // physically second column → check #
        ]
        let parsed = WeeklyReportImportParser().parse(lines: lines)
        let c = try! #require(parsed.contributions.first { $0.name.contains("Ba") })
        #expect(c.checkAmountCents == 25_000)
        #expect(c.checkNumber == "777")
        #expect(c.cashAmountCents == nil)
    }

    @Test func parsesTwoDigitYearDate() {
        // A handwritten "6/29/25" must read as 2025, not the year 25 A.D.
        // (DateFormatter's "yyyy" would leniently coerce "25" → year 0025.)
        let lines = [line("Date: 6/29/25", x: 0.5, y: 0.95)]
        let parsed = WeeklyReportImportParser().parse(lines: lines)
        let date = try! #require(parsed.date)
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        #expect(comps.year == 2025)
        #expect(comps.month == 6)
        #expect(comps.day == 29)
    }

    @Test func parsesFourDigitYearDate() {
        let lines = [line("6/29/2025", x: 0.5, y: 0.95)]
        let parsed = WeeklyReportImportParser().parse(lines: lines)
        let date = try! #require(parsed.date)
        let comps = Calendar(identifier: .gregorian).dateComponents([.year], from: date)
        #expect(comps.year == 2025)
    }

    @Test func warnsWhenNothingRecognized() {
        let parsed = WeeklyReportImportParser().parse(lines: [line("random noise", x: 0.5, y: 0.5)])
        #expect(parsed.contributions.isEmpty)
        #expect(!parsed.warnings.isEmpty)
    }
}
