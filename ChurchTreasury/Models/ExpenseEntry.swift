import Foundation
import SwiftData

/// How an expense was paid. Mirrors the offering side's method concept, but
/// with the payment types a church actually writes expenses against.
enum ExpensePaymentMethod: String, Codable, CaseIterable, Identifiable {
    case check
    case online
    case zelle
    case cash

    var id: Self { self }

    var localizedName: String {
        switch self {
        case .check: String(localized: "expense.method.check")
        case .online: String(localized: "expense.method.online")
        case .zelle: String(localized: "expense.method.zelle")
        case .cash: String(localized: "expense.method.cash")
        }
    }
}

@Model
final class ExpenseEntry {
    var date: Date = Date()
    var payee: String = ""
    var amountCents: Int = 0
    var methodRaw: String = ExpensePaymentMethod.check.rawValue
    var checkNumber: String?
    var note: String?
    var createdAt: Date = Date()
    /// Whether this is a recurring "Regular" expense (pastor allowances,
    /// utilities, contributions…) vs a one-off "Special" expense. Drives the
    /// two expense sections of the monthly Operation Fund report.
    var isRegular: Bool = false
    /// Filename of a receipt/invoice photo within `AttachmentStore`'s
    /// "Expense Receipts" folder. Optional, available for any payment method.
    var receiptImageFilename: String?
    /// Filename of an image of the check written to pay this expense, within
    /// `AttachmentStore`'s "Expense Check Images" folder. Only meaningful for
    /// the `.check` method.
    var checkImageFilename: String?

    var category: Category?

    /// The recurring template this expense was recorded from, if it was added
    /// via the monthly checklist. Lets the checklist tell which regular
    /// expenses have already been entered for a given month.
    var recurringTemplate: RecurringExpense?

    /// The pending reimbursement request this expense paid off, if it was
    /// created by paying one (inverse of `ReimbursementRequest.paidExpense`).
    var reimbursementRequest: ReimbursementRequest?

    /// Set when this expense was reimbursed in cash straight out of a Sunday
    /// collection, before that collection was deposited. Such an expense
    /// reduces the batch's bank deposit and never clears the bank itself, so
    /// reconciliation must not expect a matching bank withdrawal for it.
    var paidFromBatch: OfferingBatch?

    @Relationship(inverse: \BankTransaction.matchedExpense)
    var bankTransactions: [BankTransaction]? = []

    /// Paid in cash from a collection (see `paidFromBatch`) — excluded from
    /// bank matching and already netted out of the offering's deposit.
    var isPaidFromCollection: Bool { paidFromBatch != nil }

    // The category relationship must be set after the expense is inserted
    // into a context — assigning it in the initializer crashes SwiftData.
    init(date: Date = Date(), payee: String = "", amountCents: Int = 0,
         method: ExpensePaymentMethod = .check,
         checkNumber: String? = nil, note: String? = nil) {
        self.date = date
        self.payee = payee
        self.amountCents = amountCents
        self.methodRaw = method.rawValue
        self.checkNumber = checkNumber
        self.note = note
        self.createdAt = Date()
    }

    var method: ExpensePaymentMethod {
        get { ExpensePaymentMethod(rawValue: methodRaw) ?? .check }
        set { methodRaw = newValue.rawValue }
    }

    /// Deletes any on-disk attachment files this expense owns — call before
    /// removing the expense from the context so photos don't accumulate as
    /// orphans in the Documents folders.
    func deleteAttachments() {
        if let receiptImageFilename {
            AttachmentStore.delete(receiptImageFilename, from: .expenseReceipts)
        }
        if let checkImageFilename {
            AttachmentStore.delete(checkImageFilename, from: .expenseChecks)
        }
    }
}
