import Foundation
import SwiftData
import Testing
@testable import ChurchTreasury

/// Combining duplicate donors moves their gifts onto the kept donor.
@MainActor
struct DonorMergerTests {

    // The container must outlive the context (see ReportTotalsTests).
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

    @Test func mergeMovesDonationsAndDeletesDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let keeper = Donor(name: "Hai Nguyen")
        let dupA = Donor(name: "Nguyen Hai")
        let dupB = Donor(name: "H. Nguyen", phone: "714-555-1212")
        [keeper, dupA, dupB].forEach { context.insert($0) }

        let batch = OfferingBatch(serviceDate: Date())
        context.insert(batch)

        func gift(_ cents: Int, to donor: Donor) {
            let e = DonationEntry(amountCents: cents, method: .check)
            context.insert(e)
            e.batch = batch
            if donor.donations == nil { donor.donations = [] }
            donor.donations?.append(e)
        }
        gift(5_000, to: keeper)
        gift(3_000, to: dupA)
        gift(2_000, to: dupB)

        DonorMerger.merge(into: keeper, duplicates: [dupA, dupB],
                          canonicalName: "Hai Nguyen", context: context)

        // All three gifts now belong to the kept donor.
        #expect(keeper.donations?.count == 3)
        #expect((keeper.donations ?? []).reduce(0) { $0 + $1.amountCents } == 10_000)

        // Blank contact fields backfilled from a duplicate.
        #expect(keeper.phone == "714-555-1212")

        // The other spellings are kept as aliases (real name excluded).
        #expect(Set(keeper.aliases) == ["Nguyen Hai", "H. Nguyen"])

        // Duplicates are gone; only the keeper remains.
        let remaining = try context.fetch(FetchDescriptor<Donor>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Hai Nguyen")

        // No donations were lost.
        let allEntries = try context.fetch(FetchDescriptor<DonationEntry>())
        #expect(allEntries.count == 3)
        #expect(allEntries.allSatisfy { $0.donor === keeper })
    }

    @Test func resolveMatchesAcrossVietnameseDiacritics() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existing = Donor(name: "Nguyễn Hải")
        context.insert(existing)

        // Typed without accents during import — must resolve to the same donor.
        let resolved = DonorResolver.resolveOrCreate(
            name: "nguyen hai", existing: [existing], context: context)
        #expect(resolved === existing)

        let all = try context.fetch(FetchDescriptor<Donor>())
        #expect(all.count == 1)   // no duplicate created
    }

    @Test func legalNameUsesRealNameWhenSet() {
        let donor = Donor(name: "Bác Bảy")   // treasurer's shorthand
        #expect(donor.legalName == "Bác Bảy")
        donor.realName = "Nguyen Van Bay"
        #expect(donor.legalName == "Nguyen Van Bay")
        donor.realName = "   "
        #expect(donor.legalName == "Bác Bảy")   // blank ⇒ fall back
    }

    @Test func mergeWithBrandNewNameKeepsAllSpellingsAsAliases() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let a = Donor(name: "Bay Tinh")
        let b = Donor(name: "Tinh Bay")
        [a, b].forEach { context.insert($0) }

        DonorMerger.merge(into: a, duplicates: [b],
                          canonicalName: "Nguyen Van Bay", context: context)

        #expect(a.name == "Nguyen Van Bay")
        #expect(Set(a.aliases) == ["Bay Tinh", "Tinh Bay"])

        // Importing a variant spelling now resolves to this donor, not a new one.
        let resolved = DonorResolver.resolveOrCreate(
            name: "tinh bay", existing: [a], context: context)
        #expect(resolved === a)
    }
}
