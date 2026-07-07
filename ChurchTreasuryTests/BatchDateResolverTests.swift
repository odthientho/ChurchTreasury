import Foundation
import Testing
@testable import ChurchTreasury

@MainActor
struct BatchDateResolverTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func noBatchesForDateMeansCreateNew() {
        let result = BatchDateResolver.resolve(date: date(2026, 6, 28), among: [])
        guard case .createNew = result else {
            Issue.record("Expected .createNew, got \(result)")
            return
        }
    }

    @Test func openBatchForSameDayIsReused() {
        let batch = OfferingBatch(serviceDate: date(2026, 6, 28))
        let result = BatchDateResolver.resolve(date: date(2026, 6, 28), among: [batch])
        guard case .useExisting(let matched) = result else {
            Issue.record("Expected .useExisting, got \(result)")
            return
        }
        #expect(matched === batch)
    }

    @Test func depositedBatchForSameDayNeedsChoice() {
        let batch = OfferingBatch(serviceDate: date(2026, 6, 28))
        batch.status = .deposited
        let result = BatchDateResolver.resolve(date: date(2026, 6, 28), among: [batch])
        guard case .needsDepositedChoice(let matched) = result else {
            Issue.record("Expected .needsDepositedChoice, got \(result)")
            return
        }
        #expect(matched === batch)
    }

    @Test func reconciledBatchForSameDayNeedsChoice() {
        let batch = OfferingBatch(serviceDate: date(2026, 6, 28))
        batch.status = .reconciled
        let result = BatchDateResolver.resolve(date: date(2026, 6, 28), among: [batch])
        guard case .needsDepositedChoice = result else {
            Issue.record("Expected .needsDepositedChoice, got \(result)")
            return
        }
    }

    @Test func openBatchPreferredOverDepositedOnSameDay() {
        // A treasurer previously chose "create separate collection" for a
        // deposited day — new entries should go to that open one silently,
        // no repeated prompt.
        let deposited = OfferingBatch(serviceDate: date(2026, 6, 28))
        deposited.status = .deposited
        let open = OfferingBatch(serviceDate: date(2026, 6, 28))
        let result = BatchDateResolver.resolve(date: date(2026, 6, 28), among: [deposited, open])
        guard case .useExisting(let matched) = result else {
            Issue.record("Expected .useExisting, got \(result)")
            return
        }
        #expect(matched === open)
    }

    @Test func differentDayIsIgnored() {
        let batch = OfferingBatch(serviceDate: date(2026, 6, 21))
        let result = BatchDateResolver.resolve(date: date(2026, 6, 28), among: [batch])
        guard case .createNew = result else {
            Issue.record("Expected .createNew, got \(result)")
            return
        }
    }

    @Test func sameCalendarDayDifferentTimeStillMatches() {
        let morning = Calendar.current.date(
            byAdding: .hour, value: 8, to: date(2026, 6, 28)
        )!
        let batch = OfferingBatch(serviceDate: morning)
        let evening = Calendar.current.date(
            byAdding: .hour, value: 20, to: date(2026, 6, 28)
        )!
        let result = BatchDateResolver.resolve(date: evening, among: [batch])
        guard case .useExisting(let matched) = result else {
            Issue.record("Expected .useExisting, got \(result)")
            return
        }
        #expect(matched === batch)
    }
}
