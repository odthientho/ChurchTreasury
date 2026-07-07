import Foundation
import SwiftData
import Testing
@testable import ChurchTreasury

/// Reimbursement requests: a pending request stays out of expense totals until
/// it's paid, and paying it creates a linked expense that then counts.
@MainActor
struct ReimbursementRequestTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Donor.self, OfferingBatch.self, DonationEntry.self, ExpenseEntry.self,
            RecurringExpense.self, ReimbursementRequest.self, Category.self,
            ReconciliationPeriod.self, BankStatementImport.self, BankTransaction.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func pendingRequestIsNotAnExpenseUntilPaid() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let request = ReimbursementRequest(person: "Lan Vo", detail: "Flowers",
                                           amountCents: 5_000, dateRequested: date(2026, 6, 1))
        context.insert(request)
        try context.save()

        // Pending: no expense exists yet, and the request isn't marked paid.
        #expect(!request.isPaid)
        #expect(try context.fetch(FetchDescriptor<ExpenseEntry>()).isEmpty)

        // It must not appear in the monthly report's expenses (nothing to pass in).
        let report = ReportDataBuilder.monthlyReport(
            month: date(2026, 6, 1), church: ChurchInfo(), batches: [], expenses: [])
        #expect(report.expenseTotalCents == 0)
    }

    @Test func payingRequestCreatesLinkedExpense() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let request = ReimbursementRequest(person: "Lan Vo", detail: "Flowers",
                                           amountCents: 5_000, dateRequested: date(2026, 6, 1))
        context.insert(request)

        // Simulate the pay flow: create the expense and link it to the request.
        let expense = ExpenseEntry(date: date(2026, 6, 20), payee: request.person,
                                   amountCents: request.amountCents, method: .cash,
                                   note: request.detail)
        context.insert(expense)
        expense.reimbursementRequest = request
        try context.save()

        // The request is now paid and drops out of "pending".
        #expect(request.isPaid)
        #expect(request.paidExpense === expense)

        // The expense now counts in the month's Special expenses.
        let report = ReportDataBuilder.monthlyReport(
            month: date(2026, 6, 1), church: ChurchInfo(),
            batches: [], expenses: [expense])
        #expect(report.expenseTotalCents == 5_000)
        #expect(report.specialExpenseTotalCents == 5_000)
        #expect(report.regularExpenseRows.isEmpty)
    }
}
