import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ReconcileHomeView: View {
    /// Month to reconcile; defaults to the current one when opened standalone.
    var initialMonth: Date = Date().startOfMonth

    @Environment(\.modelContext) private var context
    @Query private var periods: [ReconciliationPeriod]
    @Query(sort: \OfferingBatch.serviceDate) private var allBatches: [OfferingBatch]
    @Query(sort: \ExpenseEntry.date) private var allExpenses: [ExpenseEntry]

    @State private var selectedMonth = Date().startOfMonth
    @State private var showingImporter = false
    @State private var reviewModel: StatementImportViewModel?
    @State private var showingManualTransaction = false
    @State private var importError = false
    @State private var confirmingClose = false

    private var selectedYear: Int { Calendar.current.component(.year, from: selectedMonth) }
    private var selectedMonthNumber: Int { Calendar.current.component(.month, from: selectedMonth) }

    private var period: ReconciliationPeriod? {
        periods.first { $0.year == selectedYear && $0.month == selectedMonthNumber }
    }

    private var transactions: [BankTransaction] {
        (period?.statementImport?.transactions ?? []).sorted { $0.date < $1.date }
    }

    // MARK: - Summary math

    private var monthBatches: [OfferingBatch] {
        allBatches.filter { $0.serviceDate >= selectedMonth && $0.serviceDate < selectedMonth.startOfNextMonth }
    }

    private var monthExpenses: [ExpenseEntry] {
        allExpenses.filter { $0.date >= selectedMonth && $0.date < selectedMonth.startOfNextMonth }
    }

    private var summary: ReconciliationSummary {
        let endDate = selectedMonth.startOfNextMonth
        let inTransit = allBatches
            .filter {
                $0.status != .reconciled
                    && ($0.bankTransactions ?? []).allSatisfy { $0.matchStatus == .ignored }
                    && $0.serviceDate < endDate
            }
            .reduce(0) { $0 + $1.netDepositCents }
        let outstanding = allExpenses
            .filter {
                ($0.bankTransactions ?? []).allSatisfy { $0.matchStatus == .ignored }
                    && $0.date < endDate
                    // Cash paid from a collection never clears the bank, so it
                    // is not an outstanding check — it's already netted out of
                    // the deposit above.
                    && !$0.isPaidFromCollection
            }
            .reduce(0) { $0 + $1.amountCents }

        return ReconciliationSummary(
            beginningCents: period?.beginningBalanceCents ?? 0,
            monthIncomeCents: monthBatches.reduce(0) { $0 + $1.totalCents },
            monthExpenseCents: monthExpenses.reduce(0) { $0 + $1.amountCents },
            depositsInTransitCents: inTransit,
            outstandingChecksCents: outstanding,
            statedEndingCents: period?.statementImport?.statedEndingCents,
            unmatchedCount: transactions.count(where: { $0.matchStatus == .unmatched })
        )
    }

    var body: some View {
        NavigationStack {
            List {
                monthSelector
                statementSection
                if period?.statementImport != nil {
                    summarySection
                }
            }
            .navigationTitle(String(localized: "tab.reconcile"))
            .onAppear { selectedMonth = initialMonth.startOfMonth }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.pdf]) { result in
                handleImport(result)
            }
            .sheet(item: $reviewModel) { model in
                StatementReviewView(model: model, period: ensurePeriod())
            }
            .sheet(isPresented: $showingManualTransaction) {
                ManualTransactionSheet(period: ensurePeriod())
            }
            .alert(String(localized: "reconcile.importFailed"), isPresented: $importError) {
                Button(String(localized: "action.done"), role: .cancel) {}
            }
            .confirmationDialog(String(localized: "reconcile.closeConfirm"),
                                isPresented: $confirmingClose, titleVisibility: .visible) {
                Button(String(localized: "reconcile.closeMonth"), role: .destructive) {
                    closeMonth()
                }
            }
        }
    }

    // MARK: - Sections

    private var monthSelector: some View {
        Section {
            HStack {
                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()
                VStack(spacing: 2) {
                    Text(selectedMonth.monthYearLabel)
                        .font(.headline)
                    if let period, period.status == .closed {
                        Label(String(localized: "reconcile.closed"), systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Spacer()

                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var statementSection: some View {
        Section(String(localized: "reconcile.statement")) {
            if let statementImport = period?.statementImport {
                if let beginning = statementImport.statedBeginningCents {
                    LabeledContent(String(localized: "reconcile.statedBeginning"),
                                   value: Money.format(beginning))
                }
                if let ending = statementImport.statedEndingCents {
                    LabeledContent(String(localized: "reconcile.statedEnding"),
                                   value: Money.format(ending))
                }
                LabeledContent(String(localized: "reconcile.transactions"),
                               value: "\(transactions.count)")

                if period?.status != .closed {
                    Button(String(localized: "reconcile.reimport"), role: .destructive) {
                        showingImporter = true
                    }
                }
            } else {
                Button {
                    showingImporter = true
                } label: {
                    Label(String(localized: "reconcile.importPDF"), systemImage: "doc.badge.arrow.up")
                }
            }

            if period?.status != .closed {
                Button {
                    showingManualTransaction = true
                } label: {
                    Label(String(localized: "reconcile.manualEntry"), systemImage: "square.and.pencil")
                }
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let period {
            Section(String(localized: "reconcile.summary")) {
                NavigationLink {
                    MatchingView(period: period)
                } label: {
                    HStack {
                        Text(String(localized: "reconcile.matchTransactions"))
                        Spacer()
                        if summary.unmatchedCount > 0 {
                            Text("\(summary.unmatchedCount)")
                                .font(.callout.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.orange))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                if period.status == .open {
                    CurrencyField(titleKey: "reconcile.beginningBalance",
                                  cents: Binding(
                                    get: { period.beginningBalanceCents },
                                    set: {
                                        period.beginningBalanceCents = $0
                                        try? context.save()
                                    }
                                  ))
                } else {
                    LabeledContent(String(localized: "reconcile.beginningBalance"),
                                   value: Money.format(period.beginningBalanceCents))
                }

                LabeledContent(String(localized: "reconcile.monthIncome"),
                               value: Money.format(summary.monthIncomeCents))
                LabeledContent(String(localized: "reconcile.monthExpenses"),
                               value: Money.format(summary.monthExpenseCents))
                LabeledContent(String(localized: "reconcile.ledgerEnding"),
                               value: Money.format(summary.ledgerEndingCents))

                if summary.depositsInTransitCents > 0 {
                    LabeledContent(String(localized: "reconcile.depositsInTransit"),
                                   value: Money.format(summary.depositsInTransitCents))
                }
                if summary.outstandingChecksCents > 0 {
                    LabeledContent(String(localized: "reconcile.outstandingChecks"),
                                   value: Money.format(summary.outstandingChecksCents))
                }

                if let difference = summary.differenceCents {
                    LabeledContent(String(localized: "reconcile.difference")) {
                        HStack(spacing: 4) {
                            Text(Money.format(difference)).monospacedDigit()
                            Image(systemName: difference == 0
                                ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(difference == 0 ? Color.green : Color.orange)
                        }
                    }
                }

                if period.status == .open {
                    Button {
                        confirmingClose = true
                    } label: {
                        Label(String(localized: "reconcile.closeMonth"), systemImage: "lock")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!summary.canClose)
                }
            }
        }
    }

    private func closeMonth() {
        guard let period, summary.canClose else { return }
        period.endingBalanceCents = summary.ledgerEndingCents
        period.status = .closed
        period.closedAt = Date()
        for txn in transactions {
            if let batch = txn.matchedBatch, txn.matchStatus.isMatched {
                batch.status = .reconciled
            }
        }
        try? context.save()
    }

    // MARK: - Actions

    /// Fetches or creates the period for the selected month; the beginning
    /// balance carries forward from the previous month when available.
    private func ensurePeriod() -> ReconciliationPeriod {
        if let period { return period }
        let previous = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        let prevYear = Calendar.current.component(.year, from: previous)
        let prevMonth = Calendar.current.component(.month, from: previous)
        let carryForward = periods
            .first { $0.year == prevYear && $0.month == prevMonth }?
            .endingBalanceCents

        let newPeriod = ReconciliationPeriod(
            year: selectedYear,
            month: selectedMonthNumber,
            beginningBalanceCents: carryForward ?? 0
        )
        context.insert(newPeriod)
        try? context.save()
        return newPeriod
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let model = StatementImportViewModel()
            model.load(url: url)
            if model.loadFailed {
                importError = true
            } else {
                reviewModel = model
            }
        case .failure:
            importError = true
        }
    }
}

extension StatementImportViewModel: Identifiable {}

struct BankTransactionRow: View {
    let transaction: BankTransaction

    var body: some View {
        HStack {
            Image(systemName: transaction.section == .deposit
                ? "arrow.down.circle.fill" : "arrow.up.circle")
                .foregroundStyle(transaction.section == .deposit ? Color.green : Color.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.date, format: .dateTime.month().day())
                    Text("· \(transaction.section.localizedName)")
                    if transaction.isManuallyEntered {
                        Image(systemName: "pencil")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(transaction.amountCents))
                    .monospacedDigit()
                matchBadge
            }
        }
    }

    @ViewBuilder
    private var matchBadge: some View {
        switch transaction.matchStatus {
        case .autoMatched, .manualMatched:
            Label(String(localized: "match.matched"), systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        case .ignored:
            Text(String(localized: "match.ignored"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .unmatched:
            Text(String(localized: "match.unmatched"))
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}
