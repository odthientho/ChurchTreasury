import SwiftUI
import SwiftData

/// Pick a collection to export its Weekly Contribution Report. The same report
/// is reachable from a collection's detail page; this puts it in the Reports
/// tab too, so all report exports live in one place.
struct WeeklyReportPickerView: View {
    @Query(sort: \OfferingBatch.serviceDate, order: .reverse) private var batches: [OfferingBatch]
    @State private var previewBatch: OfferingBatch?

    var body: some View {
        Group {
            if batches.isEmpty {
                ContentUnavailableView(
                    String(localized: "report.weeklyPickerEmpty"),
                    systemImage: "doc.text",
                    description: Text(String(localized: "report.weeklyPickerEmptyDetail"))
                )
            } else {
                List(batches) { batch in
                    Button {
                        previewBatch = batch
                    } label: {
                        HStack {
                            Text(batch.serviceDate,
                                 format: .dateTime.weekday(.wide).month().day().year())
                            Spacer()
                            Text(Money.format(batch.netDepositCents))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(String(localized: "report.weeklyReport"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewBatch) { batch in
            WeeklyReportPreviewSheet(batch: batch)
        }
    }
}
