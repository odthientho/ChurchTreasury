import SwiftUI
import SwiftData

/// Manages the list of "Regular" recurring expenses (pastor allowances,
/// utilities, contributions, lawn care…). These are templates — payee,
/// description, and payment type, but no amount — used by the monthly
/// checklist to make sure each one gets recorded every month.
struct RecurringExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringExpense.sortIndex) private var templates: [RecurringExpense]
    @State private var editing: RecurringExpense?
    @State private var showingNew = false

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView(
                    String(localized: "recurring.empty.title"),
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text(String(localized: "recurring.empty.description"))
                )
            } else {
                List {
                    Section {
                        ForEach(templates) { template in
                            Button {
                                editing = template
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.detail.isEmpty ? template.payee : template.detail)
                                            .foregroundStyle(.primary)
                                        Text(template.method.map { "\($0.localizedName) · \(template.payee)" }
                                             ?? template.payee)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    } footer: {
                        Text(String(localized: "recurring.footer"))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "more.recurring"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(String(localized: "recurring.new"))
            }
            if !templates.isEmpty {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
        .sheet(isPresented: $showingNew) {
            RecurringExpenseFormView(template: nil, nextSortIndex: templates.count)
        }
        .sheet(item: $editing) { template in
            RecurringExpenseFormView(template: template, nextSortIndex: templates.count)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(templates[index]) }
        try? context.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = templates
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, template) in reordered.enumerated() { template.sortIndex = index }
        try? context.save()
    }
}

/// Add/edit form for a recurring-expense template.
private struct RecurringExpenseFormView: View {
    let template: RecurringExpense?
    let nextSortIndex: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Category> { $0.kindRaw == "expense" && !$0.isArchived },
           sort: \Category.sortOrder)
    private var categories: [Category]

    @State private var detail = ""
    @State private var payee = ""
    @State private var method: ExpensePaymentMethod?
    @State private var category: Category?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "recurring.description"), text: $detail)
                    TextField(String(localized: "expense.payee"), text: $payee)
                    Picker(String(localized: "expense.method"), selection: $method) {
                        Text(String(localized: "recurring.anyMethod")).tag(ExpensePaymentMethod?.none)
                        ForEach(ExpensePaymentMethod.allCases) { m in
                            Text(m.localizedName).tag(ExpensePaymentMethod?.some(m))
                        }
                    }
                    Picker(String(localized: "expense.category"), selection: $category) {
                        Text(String(localized: "expense.category.none")).tag(Category?.none)
                        ForEach(categories) { category in
                            Text(category.displayName).tag(Category?.some(category))
                        }
                    }
                } footer: {
                    Text(String(localized: "recurring.form.footer"))
                }
            }
            .navigationTitle(template == nil
                ? String(localized: "recurring.new")
                : String(localized: "recurring.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                        .disabled(payee.trimmingCharacters(in: .whitespaces).isEmpty
                                  && detail.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let template else { return }
        detail = template.detail
        payee = template.payee
        method = template.method
        category = template.category
    }

    private func save() {
        let target = template ?? RecurringExpense(sortIndex: nextSortIndex)
        if template == nil { context.insert(target) }
        target.detail = detail.trimmingCharacters(in: .whitespaces)
        target.payee = payee.trimmingCharacters(in: .whitespaces)
        target.method = method
        target.category = category
        try? context.save()
        dismiss()
    }
}
