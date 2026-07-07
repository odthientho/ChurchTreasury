import SwiftUI
import SwiftData

/// Add/edit a pending reimbursement request — recorded before the person is
/// actually paid back. Optional receipt photo. No payment method here: that's
/// chosen later when the request is marked paid.
struct ReimbursementRequestFormView: View {
    let request: ReimbursementRequest?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var person = ""
    @State private var detail = ""
    @State private var amountText = ""
    // Default to the collection Sunday like other expenses, so a new request
    // lands in the same month the Expenses list defaults to.
    @State private var date = Date().previousSunday
    @State private var note = ""

    @State private var receiptImage: UIImage?
    @State private var receiptDirty = false
    @State private var pendingReceiptData: Data?

    private var isValid: Bool {
        !person.trimmingCharacters(in: .whitespaces).isEmpty
            && (Money.parseCents(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "reimburse.person"), text: $person)
                    TextField(String(localized: "reimburse.detail"), text: $detail)
                    HStack {
                        Text(String(localized: "field.amount"))
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    DatePicker(String(localized: "reimburse.dateRequested"), selection: $date,
                               displayedComponents: .date)
                    TextField(String(localized: "field.note"), text: $note, axis: .vertical)
                } footer: {
                    Text(String(localized: "reimburse.form.footer"))
                }

                PhotoAttachmentSection(titleKey: "attachment.receipt", image: $receiptImage) { newImage in
                    receiptDirty = true
                    pendingReceiptData = newImage.flatMap { AttachmentStore.compressed($0) }
                }
            }
            .navigationTitle(request == nil
                ? String(localized: "reimburse.new")
                : String(localized: "reimburse.edit"))
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
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let request else { return }
        person = request.person
        detail = request.detail
        amountText = Money.formatPlain(request.amountCents).replacingOccurrences(of: ",", with: "")
        date = request.dateRequested
        note = request.note ?? ""
        if let filename = request.receiptImageFilename {
            receiptImage = AttachmentStore.load(filename, from: .expenseReceipts)
        }
    }

    private func save() {
        guard let cents = Money.parseCents(amountText) else { return }
        let target = request ?? ReimbursementRequest()
        if request == nil { context.insert(target) }
        target.person = person.trimmingCharacters(in: .whitespaces)
        target.detail = detail.trimmingCharacters(in: .whitespaces)
        target.amountCents = cents
        target.dateRequested = date
        target.note = note.isEmpty ? nil : note

        if receiptDirty {
            if let old = target.receiptImageFilename {
                AttachmentStore.delete(old, from: .expenseReceipts)
            }
            target.receiptImageFilename = pendingReceiptData.flatMap {
                AttachmentStore.save($0, in: .expenseReceipts)
            }
        }

        try? context.save()
        dismiss()
    }
}
