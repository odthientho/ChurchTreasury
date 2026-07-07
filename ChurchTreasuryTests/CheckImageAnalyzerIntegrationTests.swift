import UIKit
import Testing
@testable import ChurchTreasury

/// End-to-end: a synthetically drawn check image -> real Vision OCR ->
/// CheckOCRParser. Real recognition on a rendered (not photographed) image
/// can be imperfect, so assertions stay loose — this exists to prove the
/// pipeline runs without crashing and extracts the amount in the common case,
/// not to pin down exact OCR behavior (that's what CheckOCRParserTests do).
struct CheckImageAnalyzerIntegrationTests {

    private func makeCheckImage() -> UIImage {
        let size = CGSize(width: 1200, height: 500)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            func draw(_ text: String, at point: CGPoint, size fontSize: CGFloat = 28) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize),
                    .foregroundColor: UIColor.black,
                ]
                (text as NSString).draw(at: point, withAttributes: attributes)
            }

            draw("John A Smith", at: CGPoint(x: 40, y: 30))
            draw("123 Main St, Anytown, CA 92841", at: CGPoint(x: 40, y: 65), size: 18)
            draw("1101", at: CGPoint(x: 1050, y: 30))
            draw("DATE 6/28/2026", at: CGPoint(x: 850, y: 65), size: 18)
            draw("PAY TO THE ORDER OF Grace Community Church", at: CGPoint(x: 40, y: 220), size: 20)
            draw("$250.75", at: CGPoint(x: 950, y: 220))
            draw("Two hundred fifty and 75/100", at: CGPoint(x: 40, y: 280), size: 20)
            draw("DOLLARS", at: CGPoint(x: 900, y: 280), size: 18)
            draw("MEMO Tithe", at: CGPoint(x: 40, y: 400), size: 18)
        }
    }

    @Test func analyzesRenderedCheckWithoutCrashing() async throws {
        let image = makeCheckImage()
        let analysis = await CheckImageAnalyzer.analyze(image)

        // Compressed thumbnail always produced regardless of OCR outcome.
        #expect(analysis.storedImageData != nil)
        if let data = analysis.storedImageData {
            #expect(data.count < image.jpegData(compressionQuality: 1.0)!.count)
        }

        // Best-effort: real OCR should find at least the amount on a clean render.
        #expect(analysis.parsed.amountCents == 25_075)
    }
}
