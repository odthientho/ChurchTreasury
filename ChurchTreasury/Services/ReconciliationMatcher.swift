import Foundation

/// Proposes matches between imported bank transactions and the app's own
/// records. Pure value types in and out (indexes into the input arrays) so it
/// is unit-testable without a ModelContainer. Ambiguous cases are left
/// unmatched for the user to resolve — a wrong auto-match is worse than none.
struct ReconciliationMatcher: Sendable {

    struct TransactionInput: Sendable {
        var date: Date
        var amountCents: Int
        var section: StatementSection
        var checkNumber: String?
    }

    struct BatchInput: Sendable {
        var serviceDate: Date
        /// The net amount actually deposited (gross receipts minus any cash
        /// reimbursed out of the collection) — this is what the bank's deposit
        /// line will show.
        var depositCents: Int
    }

    struct ExpenseInput: Sendable {
        var date: Date
        var amountCents: Int
        var checkNumber: String?
    }

    enum Target: Equatable, Sendable {
        case batch(Int)
        case expense(Int)
    }

    struct Proposal: Equatable, Sendable {
        var transactionIndex: Int
        var target: Target
    }

    /// Days a deposit may lag the service date (counting Sunday, depositing Monday).
    var depositLagDays = 7
    /// Days an expense date may differ from when it clears the bank.
    var expenseSlackDays = 5

    func match(transactions: [TransactionInput],
               batches: [BatchInput],
               expenses: [ExpenseInput]) -> [Proposal] {
        var proposals: [Proposal] = []
        var usedBatches: Set<Int> = []
        var usedExpenses: Set<Int> = []
        var matchedTransactions: Set<Int> = []

        // Pass 1: check number + exact amount — the strongest signal.
        for (t, txn) in transactions.enumerated() where txn.section == .checkPaid {
            guard let checkNumber = txn.checkNumber, !checkNumber.isEmpty else { continue }
            let candidates = expenses.indices.filter { e in
                !usedExpenses.contains(e)
                    && expenses[e].checkNumber == checkNumber
                    && expenses[e].amountCents == txn.amountCents
            }
            if let match = candidates.first, candidates.count == 1 {
                proposals.append(Proposal(transactionIndex: t, target: .expense(match)))
                usedExpenses.insert(match)
                matchedTransactions.insert(t)
            }
        }

        // Pass 2: deposits — exact batch total, within the deposit lag window.
        for (t, txn) in transactions.enumerated()
        where txn.section == .deposit && !matchedTransactions.contains(t) {
            let candidates = batches.indices.filter { b in
                guard !usedBatches.contains(b) else { return false }
                let batch = batches[b]
                guard batch.depositCents == txn.amountCents else { return false }
                let lag = txn.date.timeIntervalSince(batch.serviceDate)
                return lag >= 0 && lag <= TimeInterval(depositLagDays) * 24 * 3600
            }
            if let match = candidates.first, candidates.count == 1 {
                proposals.append(Proposal(transactionIndex: t, target: .batch(match)))
                usedBatches.insert(match)
                matchedTransactions.insert(t)
            }
        }

        // Pass 3: remaining withdrawals — exact amount within the slack window.
        for (t, txn) in transactions.enumerated()
        where txn.section.isWithdrawal && !matchedTransactions.contains(t) {
            let candidates = expenses.indices.filter { e in
                guard !usedExpenses.contains(e) else { return false }
                let expense = expenses[e]
                guard expense.amountCents == txn.amountCents else { return false }
                let slack = abs(txn.date.timeIntervalSince(expense.date))
                return slack <= TimeInterval(expenseSlackDays) * 24 * 3600
            }
            if let match = candidates.first, candidates.count == 1 {
                proposals.append(Proposal(transactionIndex: t, target: .expense(match)))
                usedExpenses.insert(match)
                matchedTransactions.insert(t)
            }
        }

        return proposals
    }
}
