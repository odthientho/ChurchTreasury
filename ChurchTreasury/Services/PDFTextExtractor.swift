import Foundation
import PDFKit

enum PDFTextExtractor {
    /// Returns the text of the PDF reconstructed line-by-line from the visual
    /// layout, or nil if the file can't be opened or has no extractable text.
    ///
    /// `PDFPage.string` can merge visually separate rows into one long line,
    /// which makes statement parsing ambiguous — `selectionsByLine()` keeps
    /// each printed row on its own line.
    static func extractText(from url: URL) -> String? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { return nil }
        var lines: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            if let selection = page.selection(for: bounds) {
                for lineSelection in selection.selectionsByLine() {
                    if let line = lineSelection.string {
                        lines.append(line)
                    }
                }
            } else if let pageText = page.string {
                lines.append(pageText)
            }
        }
        let text = lines.joined(separator: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }
}
