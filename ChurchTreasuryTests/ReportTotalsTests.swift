import Foundation
import SwiftData
import Testing
@testable import ChurchTreasury

/// Report aggregation against an in-memory SwiftData container.
@MainActor
struct ReportTotalsTests {

    // The container must stay alive for the whole test — a ModelContext does
    // not retain it, and touching models after it deallocates traps.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Donor.self, OfferingBatch.self, DonationEntry.self, ExpenseEntry.self,
            RecurringExpense.self, ReimbursementRequest.self,
            Category.self, ReconciliationPeriod.self, BankStatementImport.self,
            BankTransaction.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func monthlyReportTotals() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let donor = Donor(name: "Nguyen Van A")
        context.insert(donor)

        // Two Sundays in June 2026 plus one batch outside the month.
        let june7 = OfferingBatch(serviceDate: date(2026, 6, 7))
        context.insert(june7)
        june7.bills50Count = 1                              // $50.00
        let entry1 = DonationEntry(amountCents: 100_000, method: .check, checkNumber: "1101")
        context.insert(entry1)
        entry1.donor = donor
        entry1.batch = june7
        let entry2 = DonationEntry(amountCents: 20_000, method: .envelopeCash,
                                   envelopeNumber: "12")
        context.insert(entry2)
        entry2.donor = donor
        entry2.batch = june7

        let june14 = OfferingBatch(serviceDate: date(2026, 6, 14))
        context.insert(june14)
        june14.bills10Count = 3                             // $30.00

        let mayBatch = OfferingBatch(serviceDate: date(2026, 5, 31))
        context.insert(mayBatch)
        mayBatch.bills100Count = 999                        // excluded from June report

        let category = Category(builtinKey: "cat.expense.utilities", kind: .expense)
        context.insert(category)
        let expense = ExpenseEntry(date: date(2026, 6, 20), payee: "Electric Co",
                                   amountCents: 80_055, checkNumber: "1102")
        context.insert(expense)
        expense.category = category

        let period = ReconciliationPeriod(year: 2026, month: 6, beginningBalanceCents: 1_000_000)
        context.insert(period)

        _ = period   // no longer an input to the report; net asset carries forward
        let data = ReportDataBuilder.monthlyReport(
            month: date(2026, 6, 1),
            church: ChurchInfo(name: "Test Church"),
            batches: [june7, june14, mayBatch],
            expenses: [expense],
            netAssetAnchorCents: 1_000_000,
            netAssetAnchorMonth: date(2026, 6, 1)
        )

        #expect(data.incomeRows.count == 2)
        // Contribution (gross) = checks + cash; envelope cash is NOT added (it's
        // already part of the cash count). june7 = 100,000 + 5,000 = 105,000;
        // june14 = 3,000 cash. So the month income is 108,000, not 128,000.
        #expect(data.incomeTotalCents == 108_000)
        #expect(data.incomeRows[0].contributionCents == 105_000)
        // No reimbursements, so deposit == contribution and cash-expense == 0.
        #expect(data.incomeRows[0].depositCents == 105_000)
        #expect(data.incomeRows[0].cashExpenseCents == 0)
        // The expense wasn't marked Regular, so it lands under Special.
        #expect(data.expenseTotalCents == 80_055)
        #expect(data.specialExpenseTotalCents == 80_055)
        #expect(data.regularExpenseTotalCents == 0)
        // Beginning carries from the anchor; ending = beginning + income − expense.
        #expect(data.beginningNetAssetCents == 1_000_000)
        #expect(data.endingNetAssetCents == 1_000_000 + 108_000 - 80_055)
    }

    @Test func givingStatementsPerDonorPerYear() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let donorA = Donor(name: "Tran Thi B", address: "123 Main St")
        let donorB = Donor(name: "Le Van C")
        let donorNoGiving = Donor(name: "Pham D")
        context.insert(donorA)
        context.insert(donorB)
        context.insert(donorNoGiving)

        let batch2025 = OfferingBatch(serviceDate: date(2025, 3, 2))
        let batch2026 = OfferingBatch(serviceDate: date(2026, 1, 4))
        context.insert(batch2025)
        context.insert(batch2026)

        let donation2025 = DonationEntry(amountCents: 50_000, method: .check)
        context.insert(donation2025)
        donation2025.donor = donorA
        donation2025.batch = batch2025
        let donation2026a = DonationEntry(amountCents: 30_000, method: .check)
        context.insert(donation2026a)
        donation2026a.donor = donorA
        donation2026a.batch = batch2026
        let donation2026b = DonationEntry(amountCents: 10_000, method: .envelopeCash)
        context.insert(donation2026b)
        donation2026b.donor = donorB
        donation2026b.batch = batch2026

        let statements2025 = ReportDataBuilder.givingStatements(
            year: 2025, church: ChurchInfo(), donors: [donorA, donorB, donorNoGiving]
        )
        #expect(statements2025.count == 1)
        #expect(statements2025.first?.donorName == "Tran Thi B")
        #expect(statements2025.first?.totalCents == 50_000)

        let statements2026 = ReportDataBuilder.givingStatements(
            year: 2026, church: ChurchInfo(), donors: [donorA, donorB, donorNoGiving]
        )
        #expect(statements2026.count == 2)
        #expect(statements2026.map(\.totalCents).sorted() == [10_000, 30_000])
    }

    @Test func monthlyReportPDFRendersNonEmpty() throws {
        let data = MonthlyReportPDF.render(MonthlyReportData(
            church: ChurchInfo(name: "Hội Thánh Tin Lành", address: "123 Main St",
                               treasurerName: "Thủ Quỹ"),
            month: date(2026, 6, 1),
            incomeRows: [
                .init(serviceDate: date(2026, 6, 7), eventName: "Sunday Service",
                      depositCents: 100_000, cashExpenseCents: 5_000, contributionCents: 105_000)
            ],
            regularExpenseRows: [
                .init(date: date(2026, 6, 20), typeName: "Online",
                      detail: "Electricity Bill", payee: "Georgia Power", amountCents: 56_224)
            ],
            specialExpenseRows: [
                .init(date: date(2026, 6, 1), typeName: "Check",
                      detail: "Air flight ticket", payee: "MS An", amountCents: 45_841)
            ],
            beginningNetAssetCents: 1_000_000
        ))
        #expect(data.count > 1_000)
        // %PDF header
        #expect(data.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]))
    }

    @Test func weeklyContributionReportPDFRendersNonEmpty() throws {
        var data = WeeklyContributionReportPDF.Data_()
        data.churchName = "Hội Thánh Tin Lành"
        data.date = date(2026, 6, 28)
        data.week = 4
        data.checkIncomeCents = 148_000
        data.cashIncomeCents = 151_200
        data.totalIncomeCents = 299_200
        data.cashExpensesCents = 7_900
        data.bankDepositCents = 291_300
        data.contributions = [
            .init(name: "Hải Nguyễn", checkAmountCents: 8_000, checkNumber: "143", cashAmountCents: nil),
            .init(name: "Minh Trần", checkAmountCents: nil, checkNumber: nil, cashAmountCents: 6_000),
        ]
        data.denominations = BillDenomination.allCases.map {
            .init(dollar: $0.rawValue, count: 1, amountCents: $0.rawValue * 100)
        }
        data.expenses = [.init(paidTo: "Bay Tinh", detail: "Refund for Father Day", amountCents: 7_900)]

        let pdf = WeeklyContributionReportPDF.render(data)
        #expect(pdf.count > 1_000)
        #expect(pdf.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]))
    }

    @Test func weeklyReportWeekOfMonthMatchesOrdinalSunday() {
        #expect(WeeklyContributionReportPDF.weekOfMonth(date(2026, 6, 7)) == 1)
        #expect(WeeklyContributionReportPDF.weekOfMonth(date(2026, 6, 28)) == 4)
    }

    @Test func givingStatementPDFRendersNonEmpty() throws {
        var statement = GivingStatementData(year: 2026)
        statement.church = ChurchInfo(name: "Hội Thánh Tin Lành")
        statement.donorName = "Nguyễn Văn A"
        statement.rows = [
            .init(date: date(2026, 1, 4), methodName: "Check", checkNumber: "1101",
                  amountCents: 30_000)
        ]
        let single = GivingStatementPDF.render(statement)
        #expect(single.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]))

        let all = GivingStatementPDF.renderAll([statement, statement])
        #expect(all.count > single.count)
    }
}
