import Foundation
import SwiftData
import Testing
@testable import ChurchTreasury

/// The Operation Fund monthly report: weekly deposit columns, Regular/Special
/// expense split, recurring-recorded status, and the net-asset carry-forward.
@MainActor
struct OperationFundReportTests {

    // Container must outlive the context (see ReportTotalsTests).
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Donor.self, OfferingBatch.self, DonationEntry.self, ExpenseEntry.self,
            RecurringExpense.self, ReimbursementRequest.self, Category.self, ReconciliationPeriod.self,
            BankStatementImport.self, BankTransaction.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// A batch with the given check total and loose cash (as $ whole dollars).
    @discardableResult
    private func batch(_ context: ModelContext, on serviceDate: Date,
                       checkCents: Int = 0, looseDollars: Int = 0) -> OfferingBatch {
        let b = OfferingBatch(serviceDate: serviceDate)
        context.insert(b)
        if looseDollars > 0 { b.bills1Count = looseDollars }   // $1 × N
        if checkCents > 0 {
            let e = DonationEntry(amountCents: checkCents, method: .check)
            context.insert(e)
            e.batch = b
            if b.entries == nil { b.entries = [] }
            b.entries?.append(e)
        }
        return b
    }

    @discardableResult
    private func expense(_ context: ModelContext, on date: Date, cents: Int,
                         regular: Bool, payee: String = "Payee",
                         paidFrom: OfferingBatch? = nil) -> ExpenseEntry {
        let e = ExpenseEntry(date: date, payee: payee, amountCents: cents, method: .check)
        context.insert(e)
        e.isRegular = regular
        if let paidFrom {
            e.paidFromBatch = paidFrom
            if paidFrom.cashReimbursements == nil { paidFrom.cashReimbursements = [] }
            paidFrom.cashReimbursements?.append(e)
        }
        return e
    }

    @Test func weeklyDepositColumnsSplitDepositCashExpenseContribution() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // $1,000 check + $500 loose = $1,500 gross; $200 cash reimbursed.
        let b = batch(context, on: date(2026, 6, 7), checkCents: 100_000, looseDollars: 500)
        expense(context, on: date(2026, 6, 7), cents: 20_000, regular: false,
                payee: "Sam", paidFrom: b)

        let data = ReportDataBuilder.monthlyReport(
            month: date(2026, 6, 1), church: ChurchInfo(),
            batches: [b], expenses: b.cashReimbursements ?? [])

        #expect(data.incomeRows.count == 1)
        let row = data.incomeRows[0]
        #expect(row.contributionCents == 150_000)   // gross
        #expect(row.cashExpenseCents == 20_000)     // reimbursed from collection
        #expect(row.depositCents == 130_000)        // what reached the bank
        #expect(data.incomeTotalCents == 150_000)
        #expect(data.depositTotalCents == 130_000)
        #expect(data.cashExpenseTotalCents == 20_000)
        // The reimbursement is a Special expense too (double-entry).
        #expect(data.specialExpenseTotalCents == 20_000)
        #expect(data.regularExpenseTotalCents == 0)
    }

    @Test func expensesSplitRegularVsSpecial() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let b = batch(context, on: date(2026, 6, 7), checkCents: 0, looseDollars: 0)
        expense(context, on: date(2026, 6, 10), cents: 60_000, regular: true, payee: "Georgia Power")
        expense(context, on: date(2026, 6, 12), cents: 40_000, regular: false, payee: "Guest Speaker")
        let all = try context.fetch(FetchDescriptor<ExpenseEntry>())

        let data = ReportDataBuilder.monthlyReport(
            month: date(2026, 6, 1), church: ChurchInfo(), batches: [b], expenses: all)

        #expect(data.regularExpenseRows.count == 1)
        #expect(data.specialExpenseRows.count == 1)
        #expect(data.regularExpenseTotalCents == 60_000)
        #expect(data.specialExpenseTotalCents == 40_000)
        #expect(data.expenseTotalCents == 100_000)
    }

    @Test func netAssetCarriesForwardBetweenMonths() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // May: +$1,000 income, −$300 expense.  June: +$2,000 income, −$500.
        let may = batch(context, on: date(2026, 5, 31), looseDollars: 1_000)   // $1,000
        let june = batch(context, on: date(2026, 6, 7), looseDollars: 2_000)   // $2,000
        expense(context, on: date(2026, 5, 15), cents: 30_000, regular: true)
        expense(context, on: date(2026, 6, 15), cents: 50_000, regular: true)
        let allBatches = [may, june]
        let allExpenses = try context.fetch(FetchDescriptor<ExpenseEntry>())

        // Anchor: $10,000 net asset at the start of May 2026.
        let anchorCents = 1_000_000
        let anchorMonth = date(2026, 5, 1)

        let mayReport = ReportDataBuilder.monthlyReport(
            month: date(2026, 5, 1), church: ChurchInfo(),
            batches: allBatches, expenses: allExpenses,
            netAssetAnchorCents: anchorCents, netAssetAnchorMonth: anchorMonth)
        #expect(mayReport.beginningNetAssetCents == 1_000_000)
        #expect(mayReport.endingNetAssetCents == 1_000_000 + 100_000 - 30_000)   // 1,070,000

        let juneReport = ReportDataBuilder.monthlyReport(
            month: date(2026, 6, 1), church: ChurchInfo(),
            batches: allBatches, expenses: allExpenses,
            netAssetAnchorCents: anchorCents, netAssetAnchorMonth: anchorMonth)
        // June's beginning == May's ending (carry-forward).
        #expect(juneReport.beginningNetAssetCents == mayReport.endingNetAssetCents)
        #expect(juneReport.endingNetAssetCents == 1_070_000 + 200_000 - 50_000)   // 1,220,000
    }

    @Test func recurringRecordedStatusAndMissingList() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let electricity = RecurringExpense(payee: "Georgia Power", detail: "Electricity Bill")
        let water = RecurringExpense(payee: "Gwinnett County", detail: "Water Bill")
        context.insert(electricity)
        context.insert(water)

        // Record electricity for June, leave water unrecorded.
        let e = ExpenseEntry(date: date(2026, 6, 10), payee: "Georgia Power",
                             amountCents: 56_224, method: .online)
        context.insert(e)
        e.isRegular = true
        e.recurringTemplate = electricity
        if electricity.expenses == nil { electricity.expenses = [] }
        electricity.expenses?.append(e)

        #expect(electricity.isRecorded(inMonthOf: date(2026, 6, 1)))
        #expect(!electricity.isRecorded(inMonthOf: date(2026, 7, 1)))
        #expect(!water.isRecorded(inMonthOf: date(2026, 6, 1)))

        let data = ReportDataBuilder.monthlyReport(
            month: date(2026, 6, 1), church: ChurchInfo(),
            batches: [], expenses: [e], recurring: [electricity, water])
        #expect(data.missingRegularNames == ["Water Bill"])
    }
}
