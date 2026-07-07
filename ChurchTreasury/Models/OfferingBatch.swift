import Foundation
import SwiftData

enum BatchStatus: String, Codable, CaseIterable {
    case open
    case deposited
    case reconciled

    var localizedName: String {
        switch self {
        case .open: String(localized: "batch.status.open")
        case .deposited: String(localized: "batch.status.deposited")
        case .reconciled: String(localized: "batch.status.reconciled")
        }
    }
}

/// US bill denominations countable in the loose-cash form. Bills only, no
/// coins — loose cash totals are always whole dollars.
enum BillDenomination: Int, CaseIterable, Identifiable, Hashable {
    case one = 1, two = 2, five = 5, ten = 10, twenty = 20, fifty = 50, hundred = 100

    var id: Int { rawValue }
    var label: String { "$\(rawValue)" }
}

/// One Sunday (or special service) collection. Checks and envelope cash are
/// itemized as `DonationEntry` rows; loose cash is counted by bill
/// denomination since it is never attributable to a donor.
@Model
final class OfferingBatch {
    var serviceDate: Date = Date()
    var note: String?
    var statusRaw: String = BatchStatus.open.rawValue
    var bills1Count: Int = 0
    var bills2Count: Int = 0
    var bills5Count: Int = 0
    var bills10Count: Int = 0
    var bills20Count: Int = 0
    var bills50Count: Int = 0
    var bills100Count: Int = 0
    var createdAt: Date = Date()
    /// Filename of the bank deposit receipt photo (in `AttachmentStore`'s
    /// "Deposit Receipts" folder), attached when the collection is deposited.
    var depositReceiptImageFilename: String?

    @Relationship(deleteRule: .cascade, inverse: \DonationEntry.batch)
    var entries: [DonationEntry]? = []

    @Relationship(inverse: \BankTransaction.matchedBatch)
    var bankTransactions: [BankTransaction]? = []

    /// Cash expenses reimbursed out of this collection before it was deposited.
    /// Nullify on batch delete (not cascade) — the money was still spent, so
    /// the expense should survive as a regular cash expense.
    @Relationship(inverse: \ExpenseEntry.paidFromBatch)
    var cashReimbursements: [ExpenseEntry]? = []

    init(serviceDate: Date = Date(), note: String? = nil) {
        self.serviceDate = serviceDate
        self.note = note
        self.statusRaw = BatchStatus.open.rawValue
        self.createdAt = Date()
    }

    var status: BatchStatus {
        get { BatchStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    func count(for denomination: BillDenomination) -> Int {
        get(denomination)
    }

    func setCount(_ count: Int, for denomination: BillDenomination) {
        switch denomination {
        case .one: bills1Count = count
        case .two: bills2Count = count
        case .five: bills5Count = count
        case .ten: bills10Count = count
        case .twenty: bills20Count = count
        case .fifty: bills50Count = count
        case .hundred: bills100Count = count
        }
    }

    private func get(_ denomination: BillDenomination) -> Int {
        switch denomination {
        case .one: bills1Count
        case .two: bills2Count
        case .five: bills5Count
        case .ten: bills10Count
        case .twenty: bills20Count
        case .fifty: bills50Count
        case .hundred: bills100Count
        }
    }

    var checksCents: Int {
        (entries ?? []).filter { $0.method == .check }.reduce(0) { $0 + $1.amountCents }
    }

    var envelopeCashCents: Int {
        (entries ?? []).filter { $0.method == .envelopeCash }.reduce(0) { $0 + $1.amountCents }
    }

    /// The actual total cash received, counted by bill denomination. Cash
    /// that came in donor envelopes is dropped into this same count, so this
    /// already includes envelope cash — envelope entries exist only to
    /// attribute that cash to donors, not to add to it.
    var looseCashCents: Int {
        BillDenomination.allCases.reduce(0) { $0 + $1.rawValue * count(for: $1) } * 100
    }

    /// Gross offering received: checks plus all counted cash. This is the
    /// income figure for reports and the ledger. Envelope-cash entries are
    /// deliberately excluded — that money is already part of `looseCashCents`;
    /// adding it would double-count.
    var totalCents: Int {
        checksCents + looseCashCents
    }

    /// Total reimbursed in cash out of this collection before deposit.
    var cashReimbursementsCents: Int {
        (cashReimbursements ?? []).reduce(0) { $0 + $1.amountCents }
    }

    /// What actually reaches the bank: gross receipts minus any cash paid out
    /// of the collection on the spot. This is the amount reconciliation matches
    /// against the bank's deposit line.
    var netDepositCents: Int {
        totalCents - cashReimbursementsCents
    }

    /// Removes the deposit-receipt file, if any — call before deleting the
    /// batch so the photo doesn't linger as an orphan in the Documents folder.
    func deleteAttachments() {
        if let depositReceiptImageFilename {
            AttachmentStore.delete(depositReceiptImageFilename, from: .depositReceipts)
        }
    }
}
