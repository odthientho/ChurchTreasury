import SwiftUI
import SwiftData

struct OfferingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \OfferingBatch.serviceDate, order: .reverse) private var batches: [OfferingBatch]
    @Query(sort: \Donor.name) private var donors: [Donor]
    @State private var path: [OfferingBatch] = []
    @State private var scanMethod: DonationMethod?
    @State private var showingLooseCash = false
    @State private var showingImport = false
    // Default to the month of the current collection Sunday (not the raw
    // calendar month) so a freshly-recorded offering — which dates to the
    // most recent Sunday — is always visible under the default filter, even
    // in the first days of a month before its first Sunday.
    @State private var selectedMonth: Date = Date().previousSunday.startOfMonth

    /// The weeks that fall within the currently-filtered month.
    private var monthBatches: [OfferingBatch] {
        batches.filter {
            Calendar.current.isDate($0.serviceDate, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    /// The month's total offering income (gross, before any cash reimbursed on
    /// the spot) — the real income received, matching each week's row.
    private var monthTotal: Int {
        monthBatches.reduce(0) { $0 + $1.totalCents }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if monthBatches.isEmpty {
                    ContentUnavailableView(
                        selectedMonth.monthYearLabel,
                        systemImage: "heart.circle",
                        description: Text(String(localized: "offerings.monthEmpty"))
                    )
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(monthBatches) { batch in
                            NavigationLink(value: batch) {
                                BatchRow(batch: batch)
                            }
                        }
                        .onDelete(perform: deleteBatches)
                    } header: {
                        HStack {
                            Text(String(localized: "offerings.weeks"))
                            Spacer()
                            Text(Money.format(monthTotal))
                                .monospacedDigit()
                        }
                    }
                }
            }
            // Fixed header (title + scan button + quick buttons + month filter)
            // pinned above the list, so only the weeks list itself scrolls.
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    header
                    quickEntryRow
                        .padding(.horizontal)
                    MonthFilterBar(month: $selectedMonth)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
                .background(Color(.systemGroupedBackground))
            }
            // Title still set (so pushed detail views get a proper
            // "‹ Offerings" back button) but the bar itself is hidden — the
            // title is drawn in-content via `header`, with the scan button
            // sitting right next to it.
            .navigationTitle(String(localized: "tab.offerings"))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: OfferingBatch.self) { batch in
                OfferingBatchDetailView(batch: batch)
            }
            .sheet(item: $scanMethod) { method in
                CheckScanSheet(donors: donors, method: method)
            }
            .sheet(isPresented: $showingLooseCash) {
                LooseCashSheet()
            }
            .sheet(isPresented: $showingImport) {
                WeeklyReportImportSheet(donors: donors)
            }
        }
    }

    // Screen title with the "scan a whole weekly report" action sitting right
    // next to the word — replaces the old top-right toolbar button.
    private var header: some View {
        HStack(spacing: 10) {
            Text(String(localized: "tab.offerings"))
                .font(.largeTitle.bold())
            Button {
                showingImport = true
            } label: {
                Image(systemName: "doc.text.viewfinder")
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "import.title"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var quickEntryRow: some View {
        HStack(spacing: 10) {
            QuickEntryButton(
                titleKey: "offering.checks", systemImage: "pencil.and.list.clipboard",
                color: .blue
            ) {
                scanMethod = .check
            }
            QuickEntryButton(
                titleKey: "offering.envelopes", systemImage: "envelope.fill",
                color: .teal
            ) {
                scanMethod = .envelopeCash
            }
            QuickEntryButton(
                titleKey: "offering.looseCash", systemImage: "banknote.fill",
                color: .green
            ) {
                showingLooseCash = true
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteBatches(at offsets: IndexSet) {
        for index in offsets {
            let batch = monthBatches[index]
            batch.deleteAttachments()
            context.delete(batch)
        }
        try? context.save()
    }
}

private struct QuickEntryButton: View {
    let titleKey: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(String(localized: String.LocalizationValue(titleKey)))
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            // Fixed size (not just equal width via the HStack) so all three
            // buttons match regardless of how many lines their label wraps to.
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: String.LocalizationValue(titleKey)))
    }
}

private struct BatchRow: View {
    let batch: OfferingBatch

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(batch.serviceDate, format: .dateTime.weekday(.wide).month().day().year())
                    .font(.body)
                Text(batch.status.localizedName)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            Spacer()
            Text(Money.format(batch.totalCents))
                .font(.body.monospacedDigit())
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch batch.status {
        case .open: .orange
        case .deposited: .blue
        case .reconciled: .green
        }
    }
}
