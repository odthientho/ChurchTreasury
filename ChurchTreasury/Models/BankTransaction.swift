import Foundation
import SwiftData

enum StatementSection: String, Codable, CaseIterable {
    case deposit
    case checkPaid
    case atmDebit
    case electronic
    case fee

    var isWithdrawal: Bool { self != .deposit }

    var localizedName: String {
        switch self {
        case .deposit: String(localized: "txn.section.deposit")
        case .checkPaid: String(localized: "txn.section.checkPaid")
        case .atmDebit: String(localized: "txn.section.atmDebit")
        case .electronic: String(localized: "txn.section.electronic")
        case .fee: String(localized: "txn.section.fee")
        }
    }
}

enum MatchStatus: String, Codable {
    case unmatched
    case autoMatched
    case manualMatched
    case ignored

    var isMatched: Bool { self == .autoMatched || self == .manualMatched }
}

@Model
final class BankTransaction {
    var date: Date = Date()
    var descriptionText: String = ""
    /// Always positive; direction comes from the section.
    var amountCents: Int = 0
    var sectionRaw: String = StatementSection.deposit.rawValue
    var checkNumber: String?
    var matchStatusRaw: String = MatchStatus.unmatched.rawValue
    var isManuallyEntered: Bool = false

    var matchedBatch: OfferingBatch?
    var matchedExpense: ExpenseEntry?
    var statementImport: BankStatementImport?

    init(date: Date = Date(), descriptionText: String = "", amountCents: Int = 0,
         section: StatementSection = .deposit, checkNumber: String? = nil,
         isManuallyEntered: Bool = false) {
        self.date = date
        self.descriptionText = descriptionText
        self.amountCents = amountCents
        self.sectionRaw = section.rawValue
        self.checkNumber = checkNumber
        self.isManuallyEntered = isManuallyEntered
    }

    var section: StatementSection {
        get { StatementSection(rawValue: sectionRaw) ?? .deposit }
        set { sectionRaw = newValue.rawValue }
    }

    var matchStatus: MatchStatus {
        get { MatchStatus(rawValue: matchStatusRaw) ?? .unmatched }
        set { matchStatusRaw = newValue.rawValue }
    }
}
