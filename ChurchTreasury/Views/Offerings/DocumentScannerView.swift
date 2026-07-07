import SwiftUI
import VisionKit

/// A document scanner (VisionKit's `VNDocumentCameraViewController`) — the same
/// "scan a page" experience as scanning to a PDF: automatic edge detection,
/// perspective correction, and glare handling. Returns the first scanned page
/// as a `UIImage`, so it's a drop-in replacement for `CameraCaptureView`
/// everywhere the app used to take a plain photo (receipts, checks, envelopes,
/// the weekly-report import, bank deposit slips).
///
/// Only available on real devices (`VNDocumentCameraViewController.isSupported`
/// is false on the Simulator) — callers gate the "Scan" button on that.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            // A single page is all the app's flows need; take the first.
            guard scan.pageCount > 0 else { onCancel(); return }
            onCapture(scan.imageOfPage(at: 0))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            onCancel()
        }
    }
}
