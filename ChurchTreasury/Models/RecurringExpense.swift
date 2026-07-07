import Foundation
import SwiftData

/// A template for a "Regular" expense that recurs most months — pastor
/// allowances, utilities, denominational contributions, lawn care, etc. It
/// stores everything *except* the amount (which varies month to month). The
/// monthly checklist uses these to show which regular expenses have already
/// been recorded for a month and to one-tap-add the ones that haven't.
@Model
final class RecurringExpense {
    var payee: String = ""
    /// The line-item description (e.g. "Electricity Bill", "Senior Pastor Allowance").
    var detail: String = ""
    /// Optional default payment method. Left unset by default because the
    /// method sometimes changes month to month — the treasurer picks it when
    /// recording the actual expense.
    var methodRaw: String?
    /// Controls display order in the list and on the report.
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    var category: Category?

    /// Expenses that were recorded from this template (inverse of
    /// `ExpenseEntry.recurringTemplate`). Nullified, not cascaded, on delete —
    /// removing a template must never delete the real expenses already logged.
    @Relationship(inverse: \ExpenseEntry.recurringTemplate)
    var expenses: [ExpenseEntry]? = []

    init(payee: String = "", detail: String = "",
         method: ExpensePaymentMethod? = nil, sortIndex: Int = 0) {
        self.payee = payee
        self.detail = detail
        self.methodRaw = method?.rawValue
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var method: ExpensePaymentMethod? {
        get { methodRaw.flatMap(ExpensePaymentMethod.init(rawValue:)) }
        set { methodRaw = newValue?.rawValue }
    }

    /// True if an expense has already been recorded from this template within
    /// the given month.
    func isRecorded(inMonthOf date: Date) -> Bool {
        (expenses ?? []).contains {
            $0.date >= date.startOfMonth && $0.date < date.startOfNextMonth
        }
    }
}
