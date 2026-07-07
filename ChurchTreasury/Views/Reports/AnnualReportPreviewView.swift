import SwiftUI
import SwiftData

/// Preview + share for the two year-end reports: the projector "Year in Review"
/// presentation and the printable audit packet.
struct AnnualReportPreviewView: View {
    enum Kind { case presentation, audit }
    let kind: Kind

    @Query(sort: \OfferingBatch.serviceDate) private var batches: [OfferingBatch]
    @Query(sort: \ExpenseEntry.date) private var expenses: [ExpenseEntry]
    @Query(sort: \Donor.name) private var donors: [Donor]

    @AppStorage("churchName") private var churchName = ""
    @AppStorage("churchAddress") private var churchAddress = ""
    @AppStorage("treasurerName") private var treasurerName = ""
    @AppStorage("netAssetAnchorCents") private var netAssetAnchorCents = 0
    @AppStorage("netAssetAnchorMonth") private var netAssetAnchorMonth = 0.0

    @State private var year = Calendar.current.component(.year, from: Date())

    private var data: AnnualReportData {
        ReportDataBuilder.annualReport(
            year: year,
            church: ChurchInfo(name: churchName, address: churchAddress,
                               treasurerName: treasurerName, logoPNG: ChurchLogoStore.pngData()),
            batches: batches, expenses: expenses, donors: donors,
            netAssetAnchorCents: netAssetAnchorCents,
            netAssetAnchorMonth: netAssetAnchorMonth > 0
                ? Date(timeIntervalSince1970: netAssetAnchorMonth) : nil
        )
    }

    private var pdfData: Data {
        kind == .presentation ? AnnualPresentationPDF.render(data) : AnnualAuditPDF.render(data)
    }

    private var fileName: String {
        (kind == .presentation ? "year-in-review-" : "annual-audit-") + "\(year)"
    }

    private var title: String {
        String(localized: kind == .presentation ? "annual.presentationTitle" : "annual.auditTitle")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { year -= 1 } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(String(year)).font(.headline)
                Spacer()
                Button { year += 1 } label: { Image(systemName: "chevron.right") }
                    .disabled(year >= Calendar.current.component(.year, from: Date()))
            }
            .padding()

            PDFPreview(data: pdfData)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: ReportFile.url(for: pdfData, named: fileName))
            }
        }
    }
}
