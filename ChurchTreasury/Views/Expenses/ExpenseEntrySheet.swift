import SwiftUI
import SwiftData

/// Focused quick-entry screen for one expense payment method (Checks / Online
/// / Cash), mirroring the offering-side `CheckScanSheet`: the form is ready to
/// type into immediately, a receipt photo can be attached, and each added
/// expense drops into a running "added this session" list so several can be
/// entered without reopening the sheet.
struct ExpenseEntrySheet: View {
    let method: ExpensePaymentMethod

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Category> { $0.kindRaw == "expense" && !$0.isArchived },
           sort: \Category.sortOrder)
    private var categories: [Category]

    @State private var date = Date().previousSunday
    @State private var payee = ""
    @State private var amountText = ""
    @State private var checkNumber = ""
    @State private var note = ""
    @State private var category: Category?

    @State private var receiptImage: UIImage?
    @State private var pendingReceiptData: Data?

    @State private var addedExpenses: [ExpenseEntry] = []
    @State private var editingExpense: ExpenseEntry?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(String(localized: "expense.date"), selection: $date,
                               displayedComponents: .date)
                }

                Section {
                    TextField(String(localized: "expense.payee"), text: $payee)

                    HStack {
                        Text(String(localized: "field.amount"))
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }

                    Picker(String(localized: "expense.category"), selection: $category) {
                        Text(String(localized: "expense.category.none")).tag(Category?.none)
                        ForEach(categories) { category in
                            Text(category.displayName).tag(Category?.some(category))
                        }
                    }

                    if method == .check {
                        TextField(String(localized: "field.checkNumber"), text: $checkNumber)
                            .keyboardType(.numberPad)
                    }

                    TextField(String(localized: "field.note"), text: $note, axis: .vertical)

                    Button {
                        addExpense()
                    } label: {
                        Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!isValid)
                }

                PhotoAttachmentSection(titleKey: "attachment.receipt", image: $receiptImage) { newImage in
                    pendingReceiptData = newImage.flatMap { AttachmentStore.compressed($0) }
                }

                if !addedExpenses.isEmpty {
                    Section(String(localized: "offering.entries")) {
                        ForEach(addedExpenses) { expense in
                            Button {
                                editingExpense = expense
                            } label: {
                                ExpenseSessionRow(expense: expense)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteExpenses)
                        HStack {
                            Text(String(localized: "offering.total")).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(Money.format(addedExpenses.reduce(0) { $0 + $1.amountCents }))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                    }
                }
            }
            .navigationTitle(method.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.done")) { dismiss() }
                }
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseFormView(expense: expense)
            }
        }
    }

    private var isValid: Bool {
        !payee.trimmingCharacters(in: .whitespaces).isEmpty
            && (Money.parseCents(amountText) ?? 0) > 0
    }

    private func addExpense() {
        guard let cents = Money.parseCents(amountText), cents > 0 else { return }
        let expense = ExpenseEntry(
            date: date,
            payee: payee.trimmingCharacters(in: .whitespaces),
            amountCents: cents,
            method: method,
            checkNumber: method == .check && !checkNumber.isEmpty ? checkNumber : nil,
            note: note.isEmpty ? nil : note
        )
        context.insert(expense)

        if let data = pendingReceiptData {
            expense.receiptImageFilename = AttachmentStore.save(data, in: .expenseReceipts)
        }

        // Forward-array append so CategoryManagementView's expense counts stay
        // live (same convention as OfferingBatchDetailView.addEntry).
        if let category {
            if category.expenses == nil { category.expenses = [] }
            category.expenses?.append(expense)
        }
        try? context.save()
        addedExpenses.insert(expense, at: 0)

        payee = ""
        amountText = ""
        checkNumber = ""
        note = ""
        category = nil
        receiptImage = nil
        pendingReceiptData = nil
    }

    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            let expense = addedExpenses[index]
            expense.deleteAttachments()
            context.delete(expense)
        }
        addedExpenses.remove(atOffsets: offsets)
        try? context.save()
    }
}

/// Compact row for the "added this session" list: payee, method/category/#,
/// amount, and a paperclip when any attachment is present.
private struct ExpenseSessionRow: View {
    let expense: ExpenseEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.payee.isEmpty ? String(localized: "expense.payee") : expense.payee)
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if expense.receiptImageFilename != nil || expense.checkImageFilename != nil {
                Image(systemName: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(Money.format(expense.amountCents))
                .monospacedDigit()
        }
    }

    private var detailLine: String {
        var parts = [expense.method.localizedName]
        if let category = expense.category {
            parts.append(category.displayName)
        }
        if let check = expense.checkNumber, !check.isEmpty {
            parts.append("#\(check)")
        }
        return parts.joined(separator: " · ")
    }
}
