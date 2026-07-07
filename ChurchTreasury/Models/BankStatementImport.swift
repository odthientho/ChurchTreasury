import Foundation
import SwiftData

@Model
final class BankStatementImport {
    var importedAt: Date = Date()
    var fileName: String?
    var periodStart: Date?
    var periodEnd: Date?
    var statedBeginningCents: Int?
    var statedEndingCents: Int?

    var period: ReconciliationPeriod?

    @Relationship(deleteRule: .cascade, inverse: \BankTransaction.statementImport)
    var transactions: [BankTransaction]? = []

    init(fileName: String? = nil) {
        self.fileName = fileName
        self.importedAt = Date()
    }
}
