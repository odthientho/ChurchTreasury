import SwiftUI
import SwiftData

/// Matches imported bank transactions against offering batches and expenses.
struct MatchingView: View {
    let period: ReconciliationPeriod

    @Environment(\.modelContext) private var context
    @Query(sort: \OfferingBatch.serviceDate) private var allBatches: [OfferingBatch]
    @Query(sort: \ExpenseEntry.date) private var allExpenses: [ExpenseEntry]
    @State private var selectedTransaction: BankTransaction?

    private var transactions: [BankTransaction] {
        (period.statementImport?.transactions ?? []).sorted { $0.date < $1.date }
    }

    private var unmatched: [BankTransaction] {
        transactions.filter { $0.matchStatus == .unmatched }
    }

    private var resolved: [BankTransaction] {
        transactions.filter { $0.matchStatus != .unmatched }
    }

    /// Batches that could still appear on a statement (this month or earlier).
    private var candidateBatches: [OfferingBatch] {
        allBatches.filter {
            $0.status != .reconciled
                && ($0.bankTransactions ?? []).isEmpty
                && $0.serviceDate < period.endDate
        }
    }

    private var candidateExpenses: [ExpenseEntry] {
        allExpenses.filter {
            ($0.bankTransactions ?? []).isEmpty && $0.date < period.endDate
                // Cash paid out of a collection never clears the bank, so it
                // isn't a candidate for matching a statement transaction.
                && !$0.isPaidFromCollection
        }
    }

    var body: some View {
        List {
            if !unmatched.isEmpty {
                Section(String(localized: "match.unmatched")) {
                    ForEach(unmatched) { txn in
                        Button {
                            selectedTransaction = txn
                        } label: {
                            BankTransactionRow(transaction: txn)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !resolved.isEmpty {
                Section(String(localized: "match.matched")) {
                    ForEach(resolved) { txn in
                        BankTransactionRow(transaction: txn)
                            .swipeActions {
                                Button(String(localized: "match.unmatch"), role: .destructive) {
                                    unmatch(txn)
                                }
                            }
                    }
                }
            }

            outstandingSection
        }
        .navigationTitle(String(localized: "reconcile.matchTransactions"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "match.autoMatch"), systemImage: "wand.and.stars") {
                    autoMatch()
                }
                .disabled(unmatched.isEmpty)
            }
        }
        .sheet(item: $selectedTransaction) { txn in
            ManualMatchSheet(
                transaction: txn,
                candidateBatches: candidateBatches,
                candidateExpenses: candidateExpenses
            )
        }
    }

    /// App records that haven't cleared the bank yet — deposits in transit
    /// and outstanding checks.
    @ViewBuilder
    private var outstandingSection: some View {
        let batches = candidateBatches
        let expenses = candidateExpenses
        if !batches.isEmpty || !expenses.isEmpty {
            Section(String(localized: "match.outstanding")) {
                ForEach(batches) { batch in
                    HStack {
                        Image(systemName: "heart.circle")
                            .foregroundStyle(.teal)
                        Text(batch.serviceDate, format: .dateTime.month().day().year())
                        Spacer()
                        Text(Money.format(batch.netDepositCents)).monospacedDigit()
                    }
                }
                ForEach(expenses) { expense in
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.payee).lineLimit(1)
                            HStack(spacing: 4) {
                                Text(expense.date, format: .dateTime.month().day())
                                if let check = expense.checkNumber, !check.isEmpty {
                                    Text("· #\(check)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.format(expense.amountCents)).monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func autoMatch() {
        let txns = unmatched
        let batches = candidateBatches
        let expenses = candidateExpenses

        let proposals = ReconciliationMatcher().match(
            transactions: txns.map {
                .init(date: $0.date, amountCents: $0.amountCents,
                      section: $0.section, checkNumber: $0.checkNumber)
            },
            batches: batches.map {
                .init(serviceDate: $0.serviceDate, depositCents: $0.netDepositCents)
            },
            expenses: expenses.map {
                .init(date: $0.date, amountCents: $0.amountCents, checkNumber: $0.checkNumber)
            }
        )

        for proposal in proposals {
            let txn = txns[proposal.transactionIndex]
            switch proposal.target {
            case .batch(let index):
                // Append to the forward relationship array — see
                // OfferingBatchDetailView.addEntry for why setting only the
                // inverse (txn.matchedBatch) leaves other views' reads of
                // batch.bankTransactions (like the reconcile summary) stale.
                let batch = batches[index]
                if batch.bankTransactions == nil { batch.bankTransactions = [] }
                batch.bankTransactions?.append(txn)
            case .expense(let index):
                let expense = expenses[index]
                if expense.bankTransactions == nil { expense.bankTransactions = [] }
                expense.bankTransactions?.append(txn)
            }
            txn.matchStatus = .autoMatched
        }
        try? context.save()
    }

    private func unmatch(_ txn: BankTransaction) {
        txn.matchedBatch?.bankTransactions?.removeAll { $0.persistentModelID == txn.persistentModelID }
        txn.matchedExpense?.bankTransactions?.removeAll { $0.persistentModelID == txn.persistentModelID }
        txn.matchedBatch = nil
        txn.matchedExpense = nil
        txn.matchStatus = .unmatched
        try? context.save()
    }
}
