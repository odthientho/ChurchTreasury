import SwiftUI
import SwiftData

/// Resolves one unmatched bank transaction: match it to a candidate record,
/// create an expense from it (fees, autopay), or ignore it.
struct ManualMatchSheet: View {
    let transaction: BankTransaction
    let candidateBatches: [OfferingBatch]
    let candidateExpenses: [ExpenseEntry]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BankTransactionRow(transaction: transaction)
                }

                if transaction.section == .deposit {
                    batchCandidatesSection
                    Section {
                        Button {
                            createIncome()
                        } label: {
                            Label(String(localized: "match.createIncome"),
                                  systemImage: "plus.circle")
                        }
                    } footer: {
                        Text(String(localized: "match.createIncome.footer"))
                    }
                } else {
                    expenseCandidatesSection
                    Section {
                        Button {
                            createExpense()
                        } label: {
                            Label(String(localized: "match.createExpense"),
                                  systemImage: "plus.circle")
                        }
                    } footer: {
                        Text(String(localized: "match.createExpense.footer"))
                    }
                }

                Section {
                    Button(role: .destructive) {
                        transaction.matchStatus = .ignored
                        try? context.save()
                        dismiss()
                    } label: {
                        Label(String(localized: "match.ignore"), systemImage: "eye.slash")
                    }
                }
            }
            .navigationTitle(String(localized: "match.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
            }
        }
    }

    private var sortedBatches: [OfferingBatch] {
        candidateBatches.sorted {
            abs($0.netDepositCents - transaction.amountCents) < abs($1.netDepositCents - transaction.amountCents)
        }
    }

    private var sortedExpenses: [ExpenseEntry] {
        candidateExpenses.sorted {
            abs($0.amountCents - transaction.amountCents) < abs($1.amountCents - transaction.amountCents)
        }
    }

    @ViewBuilder
    private var batchCandidatesSection: some View {
        Section(String(localized: "match.candidates")) {
            if sortedBatches.isEmpty {
                Text(String(localized: "match.noCandidates"))
                    .foregroundStyle(.secondary)
            }
            ForEach(sortedBatches) { batch in
                Button {
                    // Forward-array append, not just the inverse — see
                    // OfferingBatchDetailView.addEntry for why.
                    if batch.bankTransactions == nil { batch.bankTransactions = [] }
                    batch.bankTransactions?.append(transaction)
                    transaction.matchStatus = .manualMatched
                    try? context.save()
                    dismiss()
                } label: {
                    HStack {
                        Text(batch.serviceDate, format: .dateTime.month().day().year())
                        Spacer()
                        amountLabel(batch.netDepositCents)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var expenseCandidatesSection: some View {
        Section(String(localized: "match.candidates")) {
            if sortedExpenses.isEmpty {
                Text(String(localized: "match.noCandidates"))
                    .foregroundStyle(.secondary)
            }
            ForEach(sortedExpenses) { expense in
                Button {
                    if expense.bankTransactions == nil { expense.bankTransactions = [] }
                    expense.bankTransactions?.append(transaction)
                    transaction.matchStatus = .manualMatched
                    try? context.save()
                    dismiss()
                } label: {
                    HStack {
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
                        amountLabel(expense.amountCents)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func amountLabel(_ cents: Int) -> some View {
        HStack(spacing: 4) {
            Text(Money.format(cents)).monospacedDigit()
            if cents == transaction.amountCents {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }

    private func createExpense() {
        // A bank transaction with a check number is a check payment;
        // everything else clearing the bank is an electronic/online debit.
        let expense = ExpenseEntry(
            date: transaction.date,
            payee: transaction.descriptionText,
            amountCents: transaction.amountCents,
            method: transaction.checkNumber == nil ? .online : .check,
            checkNumber: transaction.checkNumber
        )
        context.insert(expense)
        if expense.bankTransactions == nil { expense.bankTransactions = [] }
        expense.bankTransactions?.append(transaction)
        transaction.matchStatus = .manualMatched
        try? context.save()
        dismiss()
    }

    /// Records a bank deposit that wasn't in the app as income: a new
    /// collection dated to the deposit, with the amount as an anonymous entry
    /// so it counts as income and matches this transaction.
    private func createIncome() {
        let batch = OfferingBatch(serviceDate: transaction.date)
        context.insert(batch)
        let entry = DonationEntry(amountCents: transaction.amountCents, method: .check)
        context.insert(entry)
        if batch.entries == nil { batch.entries = [] }
        batch.entries?.append(entry)
        if batch.bankTransactions == nil { batch.bankTransactions = [] }
        batch.bankTransactions?.append(transaction)
        transaction.matchStatus = .manualMatched
        try? context.save()
        dismiss()
    }
}
