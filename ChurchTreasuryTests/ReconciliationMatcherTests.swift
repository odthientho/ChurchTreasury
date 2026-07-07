import Foundation
import Testing
@testable import ChurchTreasury

struct ReconciliationMatcherTests {
    private let matcher = ReconciliationMatcher()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func matchesCheckByNumberAndAmount() {
        let proposals = matcher.match(
            transactions: [.init(date: date(2026, 6, 10), amountCents: 50_000,
                                 section: .checkPaid, checkNumber: "1101")],
            batches: [],
            expenses: [
                .init(date: date(2026, 6, 1), amountCents: 50_000, checkNumber: "1101"),
                .init(date: date(2026, 6, 1), amountCents: 50_000, checkNumber: "1102"),
            ]
        )
        #expect(proposals == [.init(transactionIndex: 0, target: .expense(0))])
    }

    @Test func checkNumberMatchRequiresEqualAmount() {
        let proposals = matcher.match(
            transactions: [.init(date: date(2026, 6, 10), amountCents: 50_000,
                                 section: .checkPaid, checkNumber: "1101")],
            batches: [],
            expenses: [.init(date: date(2026, 6, 1), amountCents: 49_900, checkNumber: "1101")]
        )
        #expect(proposals.isEmpty)
    }

    @Test func matchesDepositToBatchWithinLag() {
        let proposals = matcher.match(
            transactions: [.init(date: date(2026, 6, 8), amountCents: 123_456,
                                 section: .deposit, checkNumber: nil)],
            batches: [.init(serviceDate: date(2026, 6, 7), depositCents: 123_456)],
            expenses: []
        )
        #expect(proposals == [.init(transactionIndex: 0, target: .batch(0))])
    }

    @Test func rejectsDepositBeforeServiceDate() {
        let proposals = matcher.match(
            transactions: [.init(date: date(2026, 6, 5), amountCents: 123_456,
                                 section: .deposit, checkNumber: nil)],
            batches: [.init(serviceDate: date(2026, 6, 7), depositCents: 123_456)],
            expenses: []
        )
        #expect(proposals.isEmpty)
    }

    @Test func ambiguousDepositLeftUnmatched() {
        // Two batches with the same total within the window — do not guess.
        let proposals = matcher.match(
            transactions: [.init(date: date(2026, 6, 9), amountCents: 100_000,
                                 section: .deposit, checkNumber: nil)],
            batches: [
                .init(serviceDate: date(2026, 6, 7), depositCents: 100_000),
                .init(serviceDate: date(2026, 6, 8), depositCents: 100_000),
            ],
            expenses: []
        )
        #expect(proposals.isEmpty)
    }

    @Test func matchesElectronicWithdrawalByAmountAndDate() {
        let proposals = matcher.match(
            transactions: [.init(date: date(2026, 6, 16), amountCents: 80_055,
                                 section: .electronic, checkNumber: nil)],
            batches: [],
            expenses: [.init(date: date(2026, 6, 15), amountCents: 80_055, checkNumber: nil)]
        )
        #expect(proposals == [.init(transactionIndex: 0, target: .expense(0))])
    }

    @Test func expenseNotDoubleMatched() {
        // Two identical fee transactions but only one recorded expense:
        // only one should match.
        let proposals = matcher.match(
            transactions: [
                .init(date: date(2026, 6, 16), amountCents: 2_500, section: .fee, checkNumber: nil),
                .init(date: date(2026, 6, 17), amountCents: 2_500, section: .fee, checkNumber: nil),
            ],
            batches: [],
            expenses: [.init(date: date(2026, 6, 16), amountCents: 2_500, checkNumber: nil)]
        )
        #expect(proposals.count == 1)
    }
}
