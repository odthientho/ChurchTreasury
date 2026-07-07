import Foundation
import SwiftData

/// Seeds built-in categories on first launch. Idempotent: CloudKit forbids
/// unique constraints, so we dedupe by `builtinKey` (and clean up any
/// duplicates a sync race may have created).
enum CategorySeeder {
    static let builtins: [(key: String, kind: CategoryKind, sortOrder: Int)] = [
        ("cat.income.tithe", .income, 0),
        ("cat.income.offering", .income, 1),
        ("cat.income.missions", .income, 2),
        ("cat.income.building", .income, 3),
        ("cat.income.other", .income, 99),
        ("cat.expense.utilities", .expense, 0),
        ("cat.expense.salary", .expense, 1),
        ("cat.expense.benevolence", .expense, 2),
        ("cat.expense.missions", .expense, 3),
        ("cat.expense.supplies", .expense, 4),
        ("cat.expense.maintenance", .expense, 5),
        ("cat.expense.insurance", .expense, 6),
        ("cat.expense.other", .expense, 99),
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.builtinKey != nil }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        var seen: Set<String> = []

        for category in existing {
            guard let key = category.builtinKey else { continue }
            if seen.contains(key) {
                context.delete(category)
            } else {
                seen.insert(key)
            }
        }

        for builtin in builtins where !seen.contains(builtin.key) {
            context.insert(Category(builtinKey: builtin.key,
                                    kind: builtin.kind,
                                    sortOrder: builtin.sortOrder))
        }

        try? context.save()
    }
}
