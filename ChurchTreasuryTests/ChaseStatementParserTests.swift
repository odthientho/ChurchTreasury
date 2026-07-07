import Foundation
import Testing
@testable import ChurchTreasury

struct ChaseStatementParserTests {
    private let parser = ChaseStatementParser()
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func parsesStatementPeriod() {
        let result = parser.parse(text: SampleStatements.yearBoundary)
        #expect(result.periodStart == date(2025, 12, 1))
        #expect(result.periodEnd == date(2026, 1, 5))
    }

    @Test func parsesBalances() {
        let result = parser.parse(text: SampleStatements.yearBoundary)
        #expect(result.beginningCents == 1_000_000)
        #expect(result.endingCents == 1_325_630)
    }

    @Test func parsesAllSections() {
        let result = parser.parse(text: SampleStatements.yearBoundary)
        #expect(result.transactions.count == 8)
        #expect(result.transactions.count(where: { $0.section == .deposit }) == 3)
        #expect(result.transactions.count(where: { $0.section == .checkPaid }) == 2)
        #expect(result.transactions.count(where: { $0.section == .atmDebit }) == 1)
        #expect(result.transactions.count(where: { $0.section == .electronic }) == 1)
        #expect(result.transactions.count(where: { $0.section == .fee }) == 1)
    }

    @Test func parsesCommaAmounts() {
        let result = parser.parse(text: SampleStatements.yearBoundary)
        let deposit = result.transactions.first { $0.section == .deposit }
        #expect(deposit?.amountCents == 243_210)
    }

    @Test func capturesCheckNumbers() {
        let result = parser.parse(text: SampleStatements.yearBoundary)
        let checks = result.transactions.filter { $0.section == .checkPaid }
        #expect(checks.map(\.checkNumber) == ["1101", "1102"])
        #expect(checks.map(\.amountCents) == [70_000, 50_000])
    }

    @Test func infersYearAcrossBoundary() {
        let result = parser.parse(text: SampleStatements.yearBoundary)
        let decemberDeposit = result.transactions.first { $0.section == .deposit }
        let januaryDeposit = result.transactions.filter { $0.section == .deposit }.last
        #expect(decemberDeposit?.date == date(2025, 12, 7))
        #expect(januaryDeposit?.date == date(2026, 1, 4))
    }

    @Test func consistentStatementHasNoWarnings() {
        let result = parser.parse(text: SampleStatements.yearBoundary)
        #expect(result.warnings.isEmpty)
    }

    @Test func splitsRowsMergedByPDFExtraction() {
        let result = parser.parse(text: SampleStatements.mergedRows)
        #expect(result.transactions.count == 8)
        #expect(result.transactions.count(where: { $0.section == .deposit }) == 3)
        let checks = result.transactions.filter { $0.section == .checkPaid }
        #expect(checks.map(\.checkNumber) == ["1101", "1102"])
        // Inner date in "Card Purchase 12/19 Home Depot" must not split the row
        let atm = result.transactions.first { $0.section == .atmDebit }
        #expect(atm?.amountCents == 15_025)
        #expect(result.warnings.isEmpty)
    }

    @Test func malformedLineProducesWarningAndMismatch() {
        let result = parser.parse(text: SampleStatements.malformedLine)
        // Garbled row skipped, other two parsed
        #expect(result.transactions.count == 2)
        // One warning for the unparsed line, one for the totals mismatch
        #expect(result.warnings.count == 2)
    }

    @Test func emptyTextWarns() {
        let result = parser.parse(text: "   \n  ")
        #expect(result.transactions.isEmpty)
        #expect(!result.warnings.isEmpty)
    }
}
