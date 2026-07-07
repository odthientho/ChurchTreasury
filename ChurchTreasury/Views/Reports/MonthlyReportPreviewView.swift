import SwiftUI
import SwiftData

struct MonthlyReportPreviewView: View {
    @Query(sort: \OfferingBatch.serviceDate) private var batches: [OfferingBatch]
    @Query(sort: \ExpenseEntry.date) private var expenses: [ExpenseEntry]
    @Query(sort: \RecurringExpense.sortIndex) private var recurring: [RecurringExpense]

    @AppStorage("churchName") private var churchName = ""
    @AppStorage("churchAddress") private var churchAddress = ""
    @AppStorage("treasurerName") private var treasurerName = ""
    @AppStorage("netAssetAnchorCents") private var netAssetAnchorCents = 0
    @AppStorage("netAssetAnchorMonth") private var netAssetAnchorMonth = 0.0

    @State private var showingReconcile = false

    // Default to the current month (the day the app is opened).
    @State private var selectedMonth = Date().startOfMonth

    private var report: MonthlyReportData {
        ReportDataBuilder.monthlyReport(
            month: selectedMonth,
            church: ChurchInfo(name: churchName, address: churchAddress,
                               treasurerName: treasurerName,
                               logoPNG: ChurchLogoStore.pngData()),
            batches: batches,
            expenses: expenses,
            recurring: recurring,
            netAssetAnchorCents: netAssetAnchorCents,
            netAssetAnchorMonth: netAssetAnchorMonth > 0
                ? Date(timeIntervalSince1970: netAssetAnchorMonth) : nil
        )
    }

    private var reportData: Data { MonthlyReportPDF.render(report) }

    private var fileName: String {
        let comps = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
        return "treasurer-report-\(comps.year ?? 0)-\(String(format: "%02d", comps.month ?? 0))"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(selectedMonth.monthYearLabel).font(.headline)
                Spacer()
                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()

            PDFPreview(data: reportData)
        }
        .navigationTitle(String(localized: "report.monthlyTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingReconcile = true
                } label: {
                    Label(String(localized: "reconcile.title"), systemImage: "building.columns")
                }
                ShareLink(item: ReportFile.url(for: reportData, named: fileName))
            }
        }
        .sheet(isPresented: $showingReconcile) {
            ReconcileHomeView(initialMonth: selectedMonth)
        }
    }
}
