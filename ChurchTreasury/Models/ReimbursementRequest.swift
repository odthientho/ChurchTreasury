import Foundation
import SwiftData

/// A request from someone to be paid back for money they spent for the church,
/// recorded *before* they're actually reimbursed. Kept separate from
/// `ExpenseEntry` so a pending request never counts in expense totals, the
/// monthly report, or bank reconciliation until it's paid. When the treasurer
/// pays it, an `ExpenseEntry` is created and linked here (`paidExpense`), and
/// the request drops out of the pending list.
@Model
final class ReimbursementRequest {
    /// Who asked to be reimbursed.
    var person: String = ""
    /// What the money was spent on.
    var detail: String = ""
    var amountCents: Int = 0
    var dateRequested: Date = Date()
    var note: String?
    /// Receipt/proof photo filename in `AttachmentStore`'s "Expense Receipts"
    /// folder (shared with expenses, so payment reuses the same file).
    var receiptImageFilename: String?
    var createdAt: Date = Date()

    /// The expense created when this request was paid. `nil` ⇒ still pending.
    @Relationship(inverse: \ExpenseEntry.reimbursementRequest)
    var paidExpense: ExpenseEntry?

    init(person: String = "", detail: String = "", amountCents: Int = 0,
         dateRequested: Date = Date(), note: String? = nil) {
        self.person = person
        self.detail = detail
        self.amountCents = amountCents
        self.dateRequested = dateRequested
        self.note = note
        self.createdAt = Date()
    }

    var isPaid: Bool { paidExpense != nil }

    /// Deletes the receipt file this request owns while still pending — call
    /// before deleting the request so the photo doesn't orphan. (Once paid, the
    /// created expense owns the file instead; see the pay flow.)
    func deleteAttachments() {
        if let receiptImageFilename {
            AttachmentStore.delete(receiptImageFilename, from: .expenseReceipts)
        }
    }
}
