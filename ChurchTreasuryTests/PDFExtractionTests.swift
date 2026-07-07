import Foundation
import Testing
@testable import ChurchTreasury

/// Marker class so Swift Testing can locate the test bundle.
private final class BundleMarker {}

struct PDFExtractionTests {
    /// End-to-end: real PDF file -> PDFKit text extraction -> Chase parser.
    @Test func extractsAndParsesRealPDF() throws {
        let url = try #require(
            Bundle(for: BundleMarker.self).url(forResource: "sample-statement", withExtension: "pdf")
        )
        let text = try #require(PDFTextExtractor.extractText(from: url))
        let result = ChaseStatementParser().parse(text: text)

        #expect(result.beginningCents == 1_000_000)
        #expect(result.endingCents == 1_325_630)
        #expect(result.transactions.count == 8)
        let checks = result.transactions.filter { $0.section == .checkPaid }
        #expect(checks.compactMap(\.checkNumber).sorted() == ["1101", "1102"])
    }
}
