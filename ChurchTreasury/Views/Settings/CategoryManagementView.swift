import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var newCategoryName = ""
    @State private var newCategoryKind: CategoryKind = .expense

    private func categories(of kind: CategoryKind) -> [Category] {
        categories.filter { $0.kind == kind && !$0.isArchived }
    }

    var body: some View {
        List {
            section(for: .income, titleKey: "category.income")
            section(for: .expense, titleKey: "category.expense")

            Section(String(localized: "category.new")) {
                TextField(String(localized: "category.name"), text: $newCategoryName)
                Picker(String(localized: "category.kind"), selection: $newCategoryKind) {
                    Text(String(localized: "category.income")).tag(CategoryKind.income)
                    Text(String(localized: "category.expense")).tag(CategoryKind.expense)
                }
                .pickerStyle(.segmented)
                Button(String(localized: "action.add")) {
                    addCategory()
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle(String(localized: "more.categories"))
    }

    private func section(for kind: CategoryKind, titleKey: String) -> some View {
        Section(String(localized: String.LocalizationValue(titleKey))) {
            ForEach(categories(of: kind)) { category in
                HStack {
                    Text(category.displayName)
                    Spacer()
                    if !(category.expenses ?? []).isEmpty {
                        Text("\((category.expenses ?? []).count)")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            }
            .onDelete { offsets in
                deleteCategories(of: kind, at: offsets)
            }
        }
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let maxOrder = categories(of: newCategoryKind).map(\.sortOrder).max() ?? 0
        context.insert(Category(name: name, kind: newCategoryKind, sortOrder: maxOrder + 1))
        try? context.save()
        newCategoryName = ""
    }

    /// Categories still referenced by expenses are archived (hidden) rather
    /// than deleted so history and reports stay intact.
    private func deleteCategories(of kind: CategoryKind, at offsets: IndexSet) {
        let items = categories(of: kind)
        for index in offsets {
            let category = items[index]
            if (category.expenses ?? []).isEmpty {
                context.delete(category)
            } else {
                category.isArchived = true
            }
        }
        try? context.save()
    }
}
