import Foundation
import Testing
@testable import ChurchTreasury

struct OfferingBatchTests {
    @Test func looseCashComputesFromBillCounts() {
        let batch = OfferingBatch()
        batch.bills1Count = 4
        batch.bills5Count = 2
        batch.bills20Count = 3
        // 4*1 + 2*5 + 3*20 = 74 dollars
        #expect(batch.looseCashCents == 7_400)
    }

    @Test func looseCashIsZeroWithNoBills() {
        let batch = OfferingBatch()
        #expect(batch.looseCashCents == 0)
    }

    @Test func allSevenDenominationsCountTowardTotal() {
        let batch = OfferingBatch()
        for denomination in BillDenomination.allCases {
            batch.setCount(1, for: denomination)
        }
        // 1+2+5+10+20+50+100 = 188 dollars
        #expect(batch.looseCashCents == 18_800)
    }

    @Test func setCountAndCountRoundTrip() {
        let batch = OfferingBatch()
        batch.setCount(7, for: .twenty)
        #expect(batch.count(for: .twenty) == 7)
        #expect(batch.bills20Count == 7)
    }

    @Test func totalCentsIsChecksPlusLooseCash() {
        let batch = OfferingBatch()
        batch.bills10Count = 5   // $50
        let entry = DonationEntry(amountCents: 25_000, method: .check)
        batch.entries = [entry]
        #expect(batch.totalCents == 5_000 + 25_000)
    }

    @Test func totalExcludesEnvelopeCash() {
        let batch = OfferingBatch()
        batch.bills20Count = 5   // $100 counted cash (already includes envelope cash)
        let check = DonationEntry(amountCents: 25_000, method: .check)
        let envelope = DonationEntry(amountCents: 4_000, method: .envelopeCash)
        batch.entries = [check, envelope]
        // Envelope cash is a donor record inside the loose-cash count, so the
        // deposit total is checks + loose cash only — the envelope is excluded.
        #expect(batch.totalCents == 25_000 + 10_000)
        // ...but it's still tracked for donor giving statements.
        #expect(batch.envelopeCashCents == 4_000)
    }

    @Test func netDepositSubtractsCashReimbursements() {
        let batch = OfferingBatch()
        batch.bills100Count = 2  // $200 cash
        let check = DonationEntry(amountCents: 10_000, method: .check)  // $100
        batch.entries = [check]
        let reimbursement = ExpenseEntry(amountCents: 5_000, method: .cash)  // $50 paid out
        batch.cashReimbursements = [reimbursement]

        // Gross offering (income) is unchanged: checks + cash.
        #expect(batch.totalCents == 30_000)
        #expect(batch.cashReimbursementsCents == 5_000)
        // The actual bank deposit is gross minus the cash paid out on the spot.
        #expect(batch.netDepositCents == 25_000)
    }
}
