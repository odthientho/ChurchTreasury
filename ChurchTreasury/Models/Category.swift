import Foundation
import SwiftData

enum CategoryKind: String, Codable, CaseIterable {
    case income
    case expense
}

@Model
final class Category {
    var name: String = ""
    /// Localization key for built-in categories (e.g. "cat.expense.utilities").
    /// nil for user-created categories, whose `name` is shown as-is.
    var builtinKey: String?
    var kindRaw: String = CategoryKind.expense.rawValue
    var sortOrder: Int = 0
    var isArchived: Bool = false

    @Relationship(inverse: \ExpenseEntry.category)
    var expenses: [ExpenseEntry]? = []

    init(name: String = "", builtinKey: String? = nil,
         kind: CategoryKind = .expense, sortOrder: Int = 0) {
        self.name = name
        self.builtinKey = builtinKey
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
    }

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var displayName: String {
        if let key = builtinKey {
            return String(localized: String.LocalizationValue(key))
        }
        return name
    }
}
