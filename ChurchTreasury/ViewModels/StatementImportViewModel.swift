import Foundation
import SwiftData
import Observation

/// Holds a parsed statement while the user reviews and edits it, then
/// persists the confirmed rows as a BankStatementImport for the period.
@Observable
@MainActor
final class StatementImportViewModel {

    struct EditableRow: Identifiable, Equatable {
        let id = UUID()
        var date: Date
        var descriptionText: String
        var amountCents: Int
        var section: StatementSection
        var checkNumber: String
    }

    var fileName: String = ""
    var rows: [EditableRow] = []
    var warnings: [String] = []
    var periodStart: Date?
    var periodEnd: Date?
    var statedBeginningCents: Int?
    var statedEndingCents: Int?
    var loadFailed = false

    var depositsCents: Int {
        rows.filter { $0.section == .deposit }.reduce(0) { $0 + $1.amountCents }
    }

    var withdrawalsCents: Int {
        rows.filter { $0.section.isWithdrawal }.reduce(0) { $0 + $1.amountCents }
    }

    /// stated beginning + deposits − withdrawals; compare against stated ending.
    var computedEndingCents: Int? {
        guard let beginning = statedBeginningCents else { return nil }
        return beginning + depositsCents - withdrawalsCents
    }

    func load(url: URL) {
        fileName = url.lastPathComponent
        guard let text = PDFTextExtractor.extractText(from: url) else {
            loadFailed = true
            rows = []
            warnings = [String(localized: "parser.warning.emptyText")]
            return
        }
        loadFailed = false
        let result = ChaseStatementParser().parse(text: text)
        periodStart = result.periodStart
        periodEnd = result.periodEnd
        statedBeginningCents = result.beginningCents
        statedEndingCents = result.endingCents
        warnings = result.warnings
        rows = result.transactions.map {
            EditableRow(
                date: $0.date,
                descriptionText: $0.description,
                amountCents: $0.amountCents,
                section: $0.section,
                checkNumber: $0.checkNumber ?? ""
            )
        }
    }

    /// Replaces any existing import on the period with the reviewed rows.
    func save(context: ModelContext, period: ReconciliationPeriod) {
        if let existing = period.statementImport {
            context.delete(existing)
        }

        let statementImport = BankStatementImport(fileName: fileName.isEmpty ? nil : fileName)
        statementImport.periodStart = periodStart
        statementImport.periodEnd = periodEnd
        statementImport.statedBeginningCents = statedBeginningCents
        statementImport.statedEndingCents = statedEndingCents
        context.insert(statementImport)
        // Set the side of each relationship that ReconcileHomeView actually
        // reads (period.statementImport, statementImport.transactions) —
        // SwiftData's Observation tracking keys off the mutated property, so
        // setting only the inverse leaves that view's reads stale after this
        // sheet dismisses. See OfferingBatchDetailView.addEntry for the same
        // pattern with batch.entries.
        period.statementImport = statementImport

        for row in rows {
            let txn = BankTransaction(
                date: row.date,
                descriptionText: row.descriptionText,
                amountCents: row.amountCents,
                section: row.section,
                checkNumber: row.checkNumber.isEmpty ? nil : row.checkNumber
            )
            context.insert(txn)
            if statementImport.transactions == nil { statementImport.transactions = [] }
            statementImport.transactions?.append(txn)
        }

        // SwiftData relationship changes don't reliably propagate to other
        // views' @Query results until the context saves — without this,
        // ReconcileHomeView's transaction list can appear empty after import.
        try? context.save()
    }
}
