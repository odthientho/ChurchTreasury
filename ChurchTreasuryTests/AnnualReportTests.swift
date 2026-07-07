import Foundation
import SwiftData
import Testing
@testable import ChurchTreasury

/// Year-end aggregation and that both year-end PDFs render.
@MainActor
struct AnnualReportTests {

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

    private func build(_ context: ModelContext) -> AnnualReportData {
        let donor = Donor(name: "Le Van A")
        context.insert(donor)

        // March: $1,000 check from a donor. September: $500 loose cash.
        let mar = OfferingBatch(serviceDate: date(2026, 3, 1))
        context.insert(mar)
        let gift = DonationEntry(amountCents: 100_000, method: .check)
        context.insert(gift); gift.batch = mar; gift.donor = donor
        if mar.entries == nil { mar.entries = [] }; mar.entries?.append(gift)

        let sep = OfferingBatch(serviceDate: date(2026, 9, 6))
        context.insert(sep); sep.bills100Count = 5   // $500

        // A regular and a special expense.
        let util = ExpenseEntry(date: date(2026, 3, 10), payee: "Georgia Power",
                                amountCents: 40_000, method: .online, note: "Electricity Bill")
        context.insert(util); util.isRegular = true
        let gift2 = ExpenseEntry(date: date(2026, 9, 20), payee: "Guest Speaker",
                                 amountCents: 20_000, method: .check, note: "Revival")
        context.insert(gift2)

        // An expense in a different year — excluded.
        let old = ExpenseEntry(date: date(2025, 12, 31), payee: "Old", amountCents: 99_999)
        context.insert(old)

        let batches = [mar, sep]
        let expenses = [util, gift2, old]
        return ReportDataBuilder.annualReport(
            year: 2026, church: ChurchInfo(name: "Test Church"),
            batches: batches, expenses: expenses, donors: [donor],
            netAssetAnchorCents: 1_000_000, netAssetAnchorMonth: date(2026, 1, 1))
    }

    @Test func aggregatesYearTotals() throws {
        let container = try makeContainer()
        let data = build(container.mainContext)

        #expect(data.incomeTotalCents == 150_000)          // 100,000 + 50,000
        #expect(data.expenseTotalCents == 60_000)          // 40,000 + 20,000 (2025 excluded)
        #expect(data.earningLossCents == 90_000)
        #expect(data.regularExpenseCents == 40_000)
        #expect(data.specialExpenseCents == 20_000)
        #expect(data.beginningNetAssetCents == 1_000_000)
        #expect(data.endingNetAssetCents == 1_090_000)
        #expect(data.months.count == 12)
        #expect(data.months[2].incomeCents == 100_000)     // March (index 2)
        #expect(data.months[8].incomeCents == 50_000)      // September (index 8)
        #expect(data.donorCount == 1)
        #expect(data.givingTotalCents == 100_000)
        #expect(data.incomeRows.count == 2)
        #expect(data.expenseRows.count == 2)
    }

    @Test func bothYearEndPDFsRender() throws {
        let container = try makeContainer()
        let data = build(container.mainContext)

        let presentation = AnnualPresentationPDF.render(data)
        #expect(presentation.count > 1_000)
        #expect(presentation.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]))

        let audit = AnnualAuditPDF.render(data)
        #expect(audit.count > 1_000)
        #expect(audit.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]))
    }
}
