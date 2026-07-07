import Foundation

/// The month-close math, kept as a pure value type so it is unit-testable.
///
/// Ledger side:   beginning + month income − month expenses = ledger ending
/// Bank side:     statement ending + deposits in transit − outstanding checks
/// The month can close only when both sides agree and every statement
/// transaction has been resolved.
struct ReconciliationSummary: Equatable, Sendable {
    var beginningCents = 0
    var monthIncomeCents = 0
    var monthExpenseCents = 0
    var depositsInTransitCents = 0
    var outstandingChecksCents = 0
    var statedEndingCents: Int?
    var unmatchedCount = 0

    var ledgerEndingCents: Int {
        beginningCents + monthIncomeCents - monthExpenseCents
    }

    var adjustedBankCents: Int? {
        guard let statedEndingCents else { return nil }
        return statedEndingCents + depositsInTransitCents - outstandingChecksCents
    }

    var differenceCents: Int? {
        guard let adjustedBankCents else { return nil }
        return ledgerEndingCents - adjustedBankCents
    }

    var canClose: Bool {
        unmatchedCount == 0 && differenceCents == 0
    }
}
