import SwiftUI
import SwiftData

/// Add/edit sheet for a single expense. Pass nil to create a new one, or an
/// existing expense to edit it (used both from the expense list and from the
/// quick-entry sheet's running "added this session" list).
///
/// Carries the offering-side attachment feature onto expenses: a receipt
/// photo for any expense.
struct ExpenseFormView: View {
    let expense: ExpenseEntry?
    /// Preselected payment method for a brand-new expense (from a quick button).
    var initialMethod: ExpensePaymentMethod = .check
    /// When set, a brand-new expense is pre-filled from this recurring template
    /// (payee, description, type, category), marked Regular, dated to
    /// `initialDate`, and linked to the template on save — used by the monthly
    /// checklist's one-tap "Add".
    var recurringTemplate: RecurringExpense?
    /// Default date for a brand-new expense (e.g. the report month).
    var initialDate: Date?
    /// When set, recording this new expense pays off a pending reimbursement
    /// request: it's pre-filled from the request (person, detail, amount,
    /// receipt) and linked on save so the request drops out of the pending list.
    var reimbursementRequest: ReimbursementRequest?
    /// When set, this is a cash reimbursement paid out of that Sunday's
    /// collection: the method is forced to cash and the entry is linked to the
    /// batch on save so it reduces that batch's deposit.
    var paidFromBatch: OfferingBatch?

    /// True while editing/creating a reimbursement tied to a collection.
    private var isReimbursement: Bool {
        (expense?.paidFromBatch ?? paidFromBatch) != nil
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Category> { $0.kindRaw == "expense" && !$0.isArchived },
           sort: \Category.sortOrder)
    private var categories: [Category]

    @State private var date = Date().previousSunday
    @State private var payee = ""
    @State private var amountText = ""
    @State private var method: ExpensePaymentMethod = .check
    @State private var checkNumber = ""
    @State private var note = ""
    @State private var category: Category?
    @State private var isRegular = false

    @State private var receiptImage: UIImage?
    @State private var receiptDirty = false
    @State private var pendingReceiptData: Data?

    var body: some View {
        NavigationStack {
            Form {
                if isReimbursement {
                    Section {
                        Label(String(localized: "reimbursement.paidFromCollection"),
                              systemImage: "banknote")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } footer: {
                        Text(String(localized: "reimbursement.note"))
                    }
                } else {
                    Section {
                        Picker(String(localized: "expense.method"), selection: $method) {
                            ForEach(ExpensePaymentMethod.allCases) { method in
                                Text(method.localizedName).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle(String(localized: "expense.regular"), isOn: $isRegular)
                            .disabled(recurringTemplate != nil)
                    } footer: {
                        Text(String(localized: "expense.regular.footer"))
                    }
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

                    DatePicker(String(localized: "expense.date"), selection: $date,
                               displayedComponents: .date)

                    if method == .check {
                        TextField(String(localized: "field.checkNumber"), text: $checkNumber)
                            .keyboardType(.numberPad)
                    }

                    TextField(String(localized: "field.note"), text: $note, axis: .vertical)
                }

                PhotoAttachmentSection(titleKey: "attachment.receipt", image: $receiptImage) { newImage in
                    receiptDirty = true
                    pendingReceiptData = newImage.flatMap { AttachmentStore.compressed($0) }
                }
            }
            .navigationTitle(expense == nil
                ? String(localized: "expense.new")
                : String(localized: "expense.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadExpense)
        }
    }

    private var isValid: Bool {
        !payee.trimmingCharacters(in: .whitespaces).isEmpty
            && (Money.parseCents(amountText) ?? 0) > 0
    }

    private func loadExpense() {
        guard let expense else {
            if let paidFromBatch {
                // New reimbursement: cash, dated to the collection it came from.
                method = .cash
                date = paidFromBatch.serviceDate
            } else if let template = recurringTemplate {
                // New expense pre-filled from a recurring template. The
                // template's method is optional — fall back to Check so the
                // treasurer can pick the right one for this month.
                payee = template.payee
                note = template.detail
                method = template.method ?? .check
                category = template.category
                isRegular = true
                date = initialDate ?? Date().previousSunday
            } else if let request = reimbursementRequest {
                // Paying off a pending reimbursement request: fixed person and
                // amount; the treasurer just picks how it was paid, dated today.
                payee = request.person
                note = request.detail
                amountText = Money.formatPlain(request.amountCents)
                    .replacingOccurrences(of: ",", with: "")
                method = initialMethod
                date = Date().previousSunday
                if let filename = request.receiptImageFilename {
                    receiptImage = AttachmentStore.load(filename, from: .expenseReceipts)
                }
            } else {
                method = initialMethod
                if let initialDate { date = initialDate }
            }
            return
        }
        date = expense.date
        payee = expense.payee
        amountText = Money.formatPlain(expense.amountCents).replacingOccurrences(of: ",", with: "")
        method = expense.method
        checkNumber = expense.checkNumber ?? ""
        note = expense.note ?? ""
        category = expense.category
        isRegular = expense.isRegular
        if let filename = expense.receiptImageFilename {
            receiptImage = AttachmentStore.load(filename, from: .expenseReceipts)
        }
    }

    private func save() {
        guard let cents = Money.parseCents(amountText) else { return }
        let target = expense ?? ExpenseEntry()
        if expense == nil {
            context.insert(target)
            // Link a new reimbursement to its collection via the forward array
            // (not just the inverse) so the batch's deposit/total recomputes.
            if let paidFromBatch {
                target.paidFromBatch = paidFromBatch
                if paidFromBatch.cashReimbursements == nil { paidFromBatch.cashReimbursements = [] }
                paidFromBatch.cashReimbursements?.append(target)
            }
            // Link a template-sourced expense so the checklist sees it recorded.
            if let template = recurringTemplate {
                target.recurringTemplate = template
                if template.expenses == nil { template.expenses = [] }
                template.expenses?.append(target)
            }
            // Pay off a reimbursement request: link it (marks it paid) so it
            // leaves the pending list.
            if let request = reimbursementRequest {
                target.reimbursementRequest = request
            }
        }
        target.date = date
        target.payee = payee.trimmingCharacters(in: .whitespaces)
        target.amountCents = cents
        target.method = method
        target.checkNumber = method == .check && !checkNumber.isEmpty ? checkNumber : nil
        target.note = note.isEmpty ? nil : note
        // Reimbursements are always Special; otherwise use the toggle.
        target.isRegular = isReimbursement ? false : isRegular

        persistAttachments(on: target)

        // Paying a reimbursement request: move the receipt file's ownership
        // from the request to this expense (unless the pay form set its own).
        if expense == nil, let request = reimbursementRequest {
            if receiptDirty {
                if let old = request.receiptImageFilename {
                    AttachmentStore.delete(old, from: .expenseReceipts)
                }
            } else if let filename = request.receiptImageFilename {
                target.receiptImageFilename = filename
            }
            request.receiptImageFilename = nil
        }

        // Forward-array append/remove, not just the inverse — see
        // OfferingBatchDetailView.addEntry for why this matters (here it
        // keeps CategoryManagementView's expense-count badges live).
        if target.category?.persistentModelID != category?.persistentModelID {
            target.category?.expenses?.removeAll { $0.persistentModelID == target.persistentModelID }
            if let category {
                if category.expenses == nil { category.expenses = [] }
                category.expenses?.append(target)
            } else {
                target.category = nil
            }
        }
        try? context.save()
        dismiss()
    }

    private func persistAttachments(on target: ExpenseEntry) {
        if receiptDirty {
            if let old = target.receiptImageFilename {
                AttachmentStore.delete(old, from: .expenseReceipts)
            }
            target.receiptImageFilename = pendingReceiptData.flatMap {
                AttachmentStore.save($0, in: .expenseReceipts)
            }
        }
    }
}
