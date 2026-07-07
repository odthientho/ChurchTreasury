import SwiftUI
import SwiftData

/// Adds a single bank transaction by hand — the fallback when the PDF can't
/// be parsed (or to record a missed line after import).
struct ManualTransactionSheet: View {
    let period: ReconciliationPeriod

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TransactionRowForm(title: String(localized: "txn.new"), initial: nil) { row in
            let statementImport = ensureImport()
            let txn = BankTransaction(
                date: row.date,
                descriptionText: row.descriptionText,
                amountCents: row.amountCents,
                section: row.section,
                checkNumber: row.checkNumber.isEmpty ? nil : row.checkNumber,
                isManuallyEntered: true
            )
            context.insert(txn)
            // Forward-array append, not just the inverse — see
            // OfferingBatchDetailView.addEntry for why.
            if statementImport.transactions == nil { statementImport.transactions = [] }
            statementImport.transactions?.append(txn)
            try? context.save()
        }
    }

    private func ensureImport() -> BankStatementImport {
        if let existing = period.statementImport { return existing }
        let statementImport = BankStatementImport(fileName: nil)
        context.insert(statementImport)
        period.statementImport = statementImport
        return statementImport
    }
}
