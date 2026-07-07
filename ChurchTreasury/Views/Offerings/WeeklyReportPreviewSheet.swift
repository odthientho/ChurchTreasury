import SwiftUI

/// Previews the Weekly Contribution Report for one collection and offers a
/// Share/Print action so the treasurer can keep a printed physical record.
struct WeeklyReportPreviewSheet: View {
    let batch: OfferingBatch

    @Environment(\.dismiss) private var dismiss
    @AppStorage("churchName") private var churchName = ""

    private var pdfData: Data {
        WeeklyContributionReportPDF.render(
            WeeklyContributionReportPDF.data(for: batch, churchName: churchName,
                                             logoPNG: ChurchLogoStore.pngData())
        )
    }

    private var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "weekly-contribution-\(formatter.string(from: batch.serviceDate))"
    }

    var body: some View {
        NavigationStack {
            PDFPreview(data: pdfData)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(String(localized: "report.weeklyTitle"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.done")) { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: ReportFile.url(for: pdfData, named: fileName))
                    }
                }
        }
    }
}
