import Foundation
import Testing
@testable import ChurchTreasury

/// Synthetic OCR line layouts mimicking a personal check, laid out with
/// Vision's normalized bottom-left-origin coordinates (y=1 is the top).
struct CheckOCRParserTests {
    private let parser = CheckOCRParser()

    /// A typical personal check: name/address top-left, date top-right,
    /// payee line and amount in the middle, check number top-right corner.
    private func typicalCheckLines(
        name: String = "John A Smith",
        checkNumber: String = "1101",
        amount: String = "250.75",
        date: String = "6/28/2026"
    ) -> [RecognizedTextLine] {
        [
            .init(text: checkNumber, boundingBox: CGRect(x: 0.85, y: 0.92, width: 0.1, height: 0.04)),
            .init(text: name, boundingBox: CGRect(x: 0.05, y: 0.85, width: 0.3, height: 0.05)),
            .init(text: "123 Main St, Anytown, CA 92841", boundingBox: CGRect(x: 0.05, y: 0.80, width: 0.35, height: 0.04)),
            .init(text: "DATE \(date)", boundingBox: CGRect(x: 0.7, y: 0.82, width: 0.2, height: 0.04)),
            .init(text: "PAY TO THE ORDER OF Grace Community Church", boundingBox: CGRect(x: 0.05, y: 0.65, width: 0.5, height: 0.04)),
            .init(text: "$\(amount)", boundingBox: CGRect(x: 0.75, y: 0.65, width: 0.15, height: 0.04)),
            .init(text: "Two hundred fifty and 75/100", boundingBox: CGRect(x: 0.05, y: 0.55, width: 0.6, height: 0.04)),
            .init(text: "DOLLARS", boundingBox: CGRect(x: 0.7, y: 0.55, width: 0.15, height: 0.03)),
            .init(text: "MEMO Tithe", boundingBox: CGRect(x: 0.05, y: 0.35, width: 0.2, height: 0.03)),
            .init(text: "Chase Bank", boundingBox: CGRect(x: 0.05, y: 0.28, width: 0.2, height: 0.03)),
        ]
    }

    @Test func extractsAmountFromTypicalLayout() {
        let result = parser.parse(lines: typicalCheckLines())
        #expect(result.amountCents == 25_075)
    }

    @Test func extractsAmountWithThousandsComma() {
        let result = parser.parse(lines: typicalCheckLines(amount: "1,234.56"))
        #expect(result.amountCents == 123_456)
    }

    @Test func extractsCheckNumber() {
        let result = parser.parse(lines: typicalCheckLines())
        #expect(result.checkNumber == "1101")
    }

    @Test func extractsPayerName() {
        let result = parser.parse(lines: typicalCheckLines())
        #expect(result.payerName == "John A Smith")
    }

    @Test func skipsBoilerplateWhenFindingName() {
        // No name printed above "PAY TO THE ORDER OF" — parser should not
        // mistake boilerplate or the payee line for the payer's name.
        let lines: [RecognizedTextLine] = [
            .init(text: "PAY TO THE ORDER OF Grace Community Church",
                  boundingBox: CGRect(x: 0.05, y: 0.65, width: 0.5, height: 0.04)),
            .init(text: "$50.00", boundingBox: CGRect(x: 0.75, y: 0.65, width: 0.15, height: 0.04)),
        ]
        let result = parser.parse(lines: lines)
        #expect(result.payerName == nil)
        #expect(result.warnings.contains(String(localized: "scan.warning.noName")))
    }

    @Test func extractsDate() {
        let result = parser.parse(lines: typicalCheckLines(date: "6/28/2026"))
        let calendar = Calendar(identifier: .gregorian)
        let comps = result.checkDate.map { calendar.dateComponents([.year, .month, .day], from: $0) }
        #expect(comps?.year == 2026)
        #expect(comps?.month == 6)
        #expect(comps?.day == 28)
    }

    @Test func missingAmountProducesWarning() {
        let lines: [RecognizedTextLine] = [
            .init(text: "John Smith", boundingBox: CGRect(x: 0.05, y: 0.85, width: 0.3, height: 0.05)),
        ]
        let result = parser.parse(lines: lines)
        #expect(result.amountCents == nil)
        #expect(result.warnings.contains(String(localized: "scan.warning.noAmount")))
    }

    @Test func emptyLinesProduceBothWarnings() {
        let result = parser.parse(lines: [])
        #expect(result.amountCents == nil)
        #expect(result.payerName == nil)
        #expect(result.warnings.count == 2)
    }

    @Test func ignoresMICRLineAtBottom() {
        // Garbled MICR-style text at the very bottom must not become the name.
        var lines = typicalCheckLines()
        lines.append(.init(text: "⑆123456789⑆ 0001234567⑈ 1101",
                           boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.6, height: 0.04)))
        let result = parser.parse(lines: lines)
        #expect(result.payerName == "John A Smith")
    }

    @Test func picksRightmostAmountWhenMultipleMoneyPatternsPresent() {
        // The written-out legal amount line doesn't match the money regex
        // (it's spelled out), so only the courtesy box should match even
        // when another numeric-looking value appears on the check.
        let lines = typicalCheckLines(amount: "99.99")
        let result = parser.parse(lines: lines)
        #expect(result.amountCents == 9_999)
    }
}
