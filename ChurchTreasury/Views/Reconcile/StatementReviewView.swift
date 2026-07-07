import SwiftUI
import SwiftData

/// Mandatory review step between parsing and persisting: the user can fix,
/// delete, or add rows before anything is saved.
struct StatementReviewView: View {
    @Bindable var model: StatementImportViewModel
    let period: ReconciliationPeriod

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editingRow: StatementImportViewModel.EditableRow?
    @State private var addingRow = false

    var body: some View {
        NavigationStack {
            List {
                if !model.warnings.isEmpty {
                    warningsSection
                }
                summarySection
                rowsSection
            }
            .navigationTitle(String(localized: "review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.import")) {
                        model.save(context: context, period: period)
                        dismiss()
                    }
                    .disabled(model.rows.isEmpty)
                }
            }
            .sheet(item: $editingRow) { row in
                TransactionRowForm(
                    title: String(localized: "txn.edit"),
                    initial: row
                ) { updated in
                    if let index = model.rows.firstIndex(where: { $0.id == row.id }) {
                        model.rows[index] = updated
                    }
                }
            }
            .sheet(isPresented: $addingRow) {
                TransactionRowForm(
                    title: String(localized: "txn.new"),
                    initial: nil
                ) { newRow in
                    model.rows.append(newRow)
                }
            }
        }
    }

    private var warningsSection: some View {
        Section {
            ForEach(model.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
        } header: {
            Text(String(localized: "review.warnings"))
        }
    }

    private var summarySection: some View {
        Section {
            if let beginning = model.statedBeginningCents {
                LabeledContent(String(localized: "reconcile.statedBeginning"),
                               value: Money.format(beginning))
            }
            LabeledContent(String(localized: "review.deposits"),
                           value: Money.format(model.depositsCents))
            LabeledContent(String(localized: "review.withdrawals"),
                           value: Money.format(model.withdrawalsCents))
            if let computed = model.computedEndingCents, let stated = model.statedEndingCents {
                LabeledContent(String(localized: "review.computedEnding")) {
                    HStack(spacing: 4) {
                        Text(Money.format(computed)).monospacedDigit()
                        Image(systemName: computed == stated
                            ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(computed == stated ? Color.green : Color.orange)
                    }
                }
                LabeledContent(String(localized: "reconcile.statedEnding"),
                               value: Money.format(stated))
            }
        }
    }

    private var rowsSection: some View {
        Section {
            ForEach(model.rows) { row in
                Button {
                    editingRow = row
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.descriptionText).lineLimit(1)
                            HStack(spacing: 4) {
                                Text(row.date, format: .dateTime.month().day().year())
                                Text("· \(row.section.localizedName)")
                                if !row.checkNumber.isEmpty {
                                    Text("· #\(row.checkNumber)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.format(row.amountCents))
                            .monospacedDigit()
                            .foregroundStyle(row.section == .deposit ? Color.green : Color.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                model.rows.remove(atOffsets: offsets)
            }

            Button {
                addingRow = true
            } label: {
                Label(String(localized: "review.addRow"), systemImage: "plus.circle")
            }
        } header: {
            Text(String(localized: "reconcile.transactions") + " (\(model.rows.count))")
        }
    }
}

/// Shared form for editing a parsed row or entering a new one.
struct TransactionRowForm: View {
    let title: String
    let initial: StatementImportViewModel.EditableRow?
    let onSave: (StatementImportViewModel.EditableRow) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var descriptionText = ""
    @State private var amountText = ""
    @State private var section: StatementSection = .deposit
    @State private var checkNumber = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(String(localized: "expense.date"), selection: $date,
                           displayedComponents: .date)

                TextField(String(localized: "txn.description"), text: $descriptionText)

                HStack {
                    Text(String(localized: "field.amount"))
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }

                Picker(String(localized: "txn.section"), selection: $section) {
                    ForEach(StatementSection.allCases, id: \.self) { section in
                        Text(section.localizedName).tag(section)
                    }
                }

                if section == .checkPaid {
                    TextField(String(localized: "field.checkNumber"), text: $checkNumber)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        var row = initial ?? StatementImportViewModel.EditableRow(
                            date: date, descriptionText: "", amountCents: 0,
                            section: .deposit, checkNumber: ""
                        )
                        row.date = date
                        row.descriptionText = descriptionText.trimmingCharacters(in: .whitespaces)
                        row.amountCents = Money.parseCents(amountText) ?? 0
                        row.section = section
                        row.checkNumber = section == .checkPaid ? checkNumber : ""
                        onSave(row)
                        dismiss()
                    }
                    .disabled((Money.parseCents(amountText) ?? 0) <= 0
                              || descriptionText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let initial else { return }
                date = initial.date
                descriptionText = initial.descriptionText
                amountText = Money.formatPlain(initial.amountCents)
                    .replacingOccurrences(of: ",", with: "")
                section = initial.section
                checkNumber = initial.checkNumber
            }
        }
    }
}
