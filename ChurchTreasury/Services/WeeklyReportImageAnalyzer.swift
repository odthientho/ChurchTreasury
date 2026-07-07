import Foundation
import UIKit
import Vision

/// Runs on-device text recognition over a photographed weekly-contribution
/// form and hands the positioned lines to the pure `WeeklyReportImportParser`.
/// Thin, like `CheckImageAnalyzer` — the testable logic lives in the parser.
enum WeeklyReportImageAnalyzer {

    static func analyze(_ image: UIImage) async -> ParsedWeeklyReport {
        guard let cgImage = image.cgImage else {
            var parsed = ParsedWeeklyReport()
            parsed.warnings.append(String(localized: "scan.warning.noText"))
            return parsed
        }

        // `.accurate` neural recognition reads handwriting as well as print;
        // English + Vietnamese for accented donor names. See `TextRecognition`.
        let request = TextRecognition.makeRequest(usesLanguageCorrection: false)

        do {
            let observations = try await request.perform(on: cgImage)
            let lines = observations.compactMap { observation -> RecognizedTextLine? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > 0.2
                else { return nil }
                return RecognizedTextLine(text: candidate.string,
                                          boundingBox: observation.boundingBox.cgRect)
            }
            if lines.isEmpty {
                var parsed = ParsedWeeklyReport()
                parsed.warnings.append(String(localized: "scan.warning.noText"))
                return parsed
            }
            return WeeklyReportImportParser().parse(lines: lines)
        } catch {
            var parsed = ParsedWeeklyReport()
            parsed.warnings.append(String(localized: "scan.warning.recognitionFailed"))
            return parsed
        }
    }
}
