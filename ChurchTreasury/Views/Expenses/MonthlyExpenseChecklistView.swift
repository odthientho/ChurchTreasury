import SwiftUI
import SwiftData

/// For one month, shows every recurring "Regular" expense and whether it has
/// already been recorded — so nothing is forgotten before the monthly report
/// is run. Missing items can be added in one tap, pre-filled from the template
/// (you only enter the amount).
struct MonthlyExpenseChecklistView: View {
    let month: Date

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecurringExpense.sortIndex) private var templates: [RecurringExpense]
    @State private var adding: RecurringExpense?

    /// A month-anchored date used when adding (mid-month is fine — it just
    /// needs to land inside `month`).
    private var monthDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: month.startOfMonth) ?? month.startOfMonth
    }

    private var missingCount: Int {
        templates.filter { !$0.isRecorded(inMonthOf: month) }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        String(localized: "recurring.empty.title"),
                        systemImage: "arrow.triangle.2.circlepath",
                        description: Text(String(localized: "checklist.empty.description"))
                    )
                } else {
                    List {
                        Section {
                            ForEach(templates) { template in
                                row(for: template)
                            }
                        } header: {
                            Text("\(month.monthYearLabel) · "
                                 + String(format: String(localized: "checklist.summary"),
                                          templates.count - missingCount, templates.count))
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "more.recurring"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done")) { dismiss() }
                }
            }
            .sheet(item: $adding) { template in
                ExpenseFormView(expense: nil, recurringTemplate: template, initialDate: monthDate)
            }
        }
    }

    @ViewBuilder
    private func row(for template: RecurringExpense) -> some View {
        let recorded = recordedExpense(for: template)
        HStack {
            Image(systemName: recorded != nil ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(recorded != nil ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.detail.isEmpty ? template.payee : template.detail)
                Text(template.method.map { "\($0.localizedName) · \(template.payee)" }
                     ?? template.payee)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let recorded {
                Text(Money.format(recorded.amountCents))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Button(String(localized: "checklist.add")) { adding = template }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func recordedExpense(for template: RecurringExpense) -> ExpenseEntry? {
        (template.expenses ?? []).first {
            $0.date >= month.startOfMonth && $0.date < month.startOfNextMonth
        }
    }
}
