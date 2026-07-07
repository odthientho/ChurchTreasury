import SwiftUI
import PDFKit

/// PDFKit-backed inline preview of generated report data.
struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: data)
    }
}

/// Writes report data to a temporary file so ShareLink can offer a nicely
/// named PDF.
enum ReportFile {
    static func url(for data: Data, named name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("pdf")
        try? data.write(to: url)
        return url
    }
}
