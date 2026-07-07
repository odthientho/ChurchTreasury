import Foundation
import SwiftData

enum PeriodStatus: String, Codable {
    case open
    case closed
}

/// One calendar month of reconciliation. Closing requires the app ledger
/// (beginning + income − expenses) to equal the ending balance.
@Model
final class ReconciliationPeriod {
    var year: Int = 2026
    var month: Int = 1
    var beginningBalanceCents: Int = 0
    var endingBalanceCents: Int = 0
    var statusRaw: String = PeriodStatus.open.rawValue
    var closedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \BankStatementImport.period)
    var statementImport: BankStatementImport?

    init(year: Int, month: Int, beginningBalanceCents: Int = 0) {
        self.year = year
        self.month = month
        self.beginningBalanceCents = beginningBalanceCents
        self.statusRaw = PeriodStatus.open.rawValue
    }

    var status: PeriodStatus {
        get { PeriodStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    /// First moment of the month, in the current calendar.
    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    /// First moment of the next month (exclusive upper bound).
    var endDate: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? Date()
    }
}
