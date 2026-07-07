import Foundation
import UIKit
import Vision

/// Runs on-device text recognition over a photographed check and hands the
/// result to the pure `CheckOCRParser`. Kept thin and untested beyond a
/// real-image smoke test — like `PDFTextExtractor`, the actual field logic
/// lives in the pure parser so it can be unit-tested without Vision.
enum CheckImageAnalyzer {

    struct Analysis: Sendable {
        var parsed: ParsedCheck
        var storedImageData: Data?
    }

    static func analyze(_ image: UIImage) async -> Analysis {
        let storedImageData = AttachmentStore.compressed(image)

        guard let cgImage = image.cgImage else {
            var parsed = ParsedCheck()
            parsed.warnings.append(String(localized: "scan.warning.noText"))
            return Analysis(parsed: parsed, storedImageData: storedImageData)
        }

        // `.accurate` neural recognition reads handwriting as well as print;
        // English + Vietnamese for accented names. See `TextRecognition`.
        let request = TextRecognition.makeRequest(usesLanguageCorrection: true)

        do {
            let observations = try await request.perform(on: cgImage)
            let lines = observations.compactMap { observation -> RecognizedTextLine? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > 0.3
                else { return nil }
                return RecognizedTextLine(text: candidate.string,
                                          boundingBox: observation.boundingBox.cgRect)
            }
            var parsed = CheckOCRParser().parse(lines: lines)
            if lines.isEmpty {
                parsed.warnings.append(String(localized: "scan.warning.noText"))
            }
            return Analysis(parsed: parsed, storedImageData: storedImageData)
        } catch {
            var parsed = ParsedCheck()
            parsed.warnings.append(String(localized: "scan.warning.recognitionFailed"))
            return Analysis(parsed: parsed, storedImageData: storedImageData)
        }
    }
}
