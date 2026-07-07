import SwiftUI
import SwiftData
import PhotosUI
import VisionKit

/// Imports a whole collection from a photo of the paper weekly-contribution
/// report: capture/upload → on-device OCR → an editable review of the
/// contributions, loose-cash counts, and cash expenses → creates the batch.
/// OCR is only a starting point; nothing is saved until the treasurer taps
/// Import on the reviewed data.
struct WeeklyReportImportSheet: View {
    let donors: [Donor]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private enum Phase { case capture, analyzing, review }
    @State private var phase: Phase = .capture

    @State private var showingCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var loadError = false

    @State private var serviceDate = Date().previousSunday
    @State private var contributions: [EditContribution] = []
    @State private var denominations: [Int: String] = [:]
    @State private var expenses: [EditExpense] = []
    @State private var warnings: [String] = []

    private struct EditContribution: Identifiable {
        let id = UUID()
        var name = ""
        var isCheck = true
        var amount = ""
        var checkNumber = ""
    }
    private struct EditExpense: Identifiable {
        let id = UUID()
        var paidTo = ""
        var note = ""
        var amount = ""
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "import.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.cancel")) { dismiss() }
                    }
                    if phase == .review {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "import.action")) { performImport() }
                                .disabled(!hasAnythingToImport)
                        }
                    }
                }
                .fullScreenCover(isPresented: $showingCamera) {
                    DocumentScannerView(
                        onCapture: { image in showingCamera = false; analyze(image) },
                        onCancel: { showingCamera = false }
                    )
                    .ignoresSafeArea()
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            analyze(image)
                        } else {
                            loadError = true
                        }
                        photoItem = nil
                    }
                }
                .alert(String(localized: "scan.photoLoadFailedTitle"), isPresented: $loadError) {
                    Button(String(localized: "action.done"), role: .cancel) {}
                } message: {
                    Text(String(localized: "scan.photoLoadFailed"))
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if phase == .review {
            reviewForm
        } else {
            // Keep `captureForm` (which holds the PhotosPicker) mounted while
            // analyzing — overlay the spinner rather than swapping the view
            // out. Removing a PhotosPicker from the tree while the system
            // picker is still dismissing corrupts the presentation stack and
            // dismisses this whole sheet (see the CheckScanSheet fix).
            captureForm
                .overlay {
                    if phase == .analyzing {
                        ZStack {
                            Color(.systemBackground).opacity(0.85)
                            VStack(spacing: 16) {
                                ProgressView()
                                Text(String(localized: "import.analyzing"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .ignoresSafeArea()
                    }
                }
                .disabled(phase == .analyzing)
        }
    }

    private var captureForm: some View {
        Form {
            Section {
                Text(String(localized: "import.instructions"))
                    .foregroundStyle(.secondary)
            }
            Section {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        showingCamera = true
                    } label: {
                        Label(String(localized: "scan.takePhoto"), systemImage: "doc.viewfinder")
                    }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(String(localized: "scan.chooseLibrary"), systemImage: "photo.on.rectangle")
                }
            }
        }
    }

    private var reviewForm: some View {
        Form {
            Section {
                DatePicker(String(localized: "offering.serviceDate"), selection: $serviceDate,
                           displayedComponents: .date)
            } footer: {
                if !warnings.isEmpty {
                    Text(warnings.joined(separator: "\n")).foregroundStyle(.orange)
                }
            }

            Section {
                // One offering per single line — name, check/cash, check
                // number (checks only), and amount, all inline-editable.
                ForEach($contributions) { $item in
                    HStack(spacing: 8) {
                        Picker("", selection: $item.isCheck) {
                            Text(String(localized: "import.method.check")).tag(true)
                            Text(String(localized: "import.method.cash")).tag(false)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()

                        TextField(String(localized: "field.name"), text: $item.name)
                            .textInputAutocapitalization(.words)
                            .frame(maxWidth: .infinity)

                        if item.isCheck {
                            TextField("#", text: $item.checkNumber)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 44)
                                .foregroundStyle(.secondary)
                        }

                        TextField("0.00", text: $item.amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 66)
                    }
                }
                .onDelete { contributions.remove(atOffsets: $0) }

                Button {
                    contributions.append(EditContribution())
                } label: {
                    Label(String(localized: "import.addContribution"), systemImage: "plus.circle")
                }
            } header: {
                Text(String(localized: "import.contributions"))
            } footer: {
                Text(String(localized: "import.contributionsHint"))
            }

            Section(String(localized: "offering.looseCash")) {
                ForEach(WeeklyReportImportParser.billValues, id: \.self) { value in
                    HStack {
                        Text("$\(value)")
                        Spacer()
                        TextField("0", text: denominationBinding(value))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text(String(localized: "offering.billsSuffix"))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section(String(localized: "import.expenses")) {
                ForEach($expenses) { $item in
                    VStack(spacing: 8) {
                        TextField(String(localized: "expense.payee"), text: $item.paidTo)
                        TextField(String(localized: "field.note"), text: $item.note)
                        HStack {
                            Text(String(localized: "field.amount"))
                            Spacer()
                            TextField("0.00", text: $item.amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { expenses.remove(atOffsets: $0) }

                Button {
                    expenses.append(EditExpense())
                } label: {
                    Label(String(localized: "import.addExpense"), systemImage: "plus.circle")
                }
            }
        }
    }

    // MARK: - Denomination binding

    private func denominationBinding(_ value: Int) -> Binding<String> {
        Binding(
            get: { denominations[value] ?? "" },
            set: { denominations[value] = $0 }
        )
    }

    private var hasAnythingToImport: Bool {
        contributions.contains { Money.parseCents($0.amount) ?? 0 > 0 }
            || expenses.contains { Money.parseCents($0.amount) ?? 0 > 0 }
            || denominations.values.contains { (Int($0) ?? 0) > 0 }
    }

    // MARK: - Analysis

    private func analyze(_ image: UIImage) {
        phase = .analyzing
        Task {
            // Let the system photo picker finish tearing down before the
            // capture form (which hosts the PhotosPicker) is swapped out for
            // the review form — OCR here can finish in well under the picker's
            // dismissal animation, and unmounting the picker mid-teardown
            // dismisses this whole sheet (see the CheckScanSheet fix).
            try? await Task.sleep(for: .milliseconds(600))
            let parsed = await WeeklyReportImageAnalyzer.analyze(image)
            serviceDate = parsed.date ?? Date().previousSunday
            contributions = parsed.contributions.map {
                EditContribution(
                    name: $0.name,
                    isCheck: $0.checkAmountCents != nil || $0.cashAmountCents == nil,
                    amount: Money.formatPlain($0.checkAmountCents ?? $0.cashAmountCents ?? 0)
                        .replacingOccurrences(of: ",", with: ""),
                    checkNumber: $0.checkNumber ?? ""
                )
            }
            denominations = Dictionary(uniqueKeysWithValues:
                parsed.denominationCounts.map { ($0.key, String($0.value)) })
            expenses = parsed.expenses.map {
                EditExpense(paidTo: $0.paidTo, note: $0.note,
                            amount: Money.formatPlain($0.amountCents).replacingOccurrences(of: ",", with: ""))
            }
            warnings = parsed.warnings
            if contributions.isEmpty { contributions = [EditContribution()] }
            phase = .review
        }
    }

    // MARK: - Import

    private func performImport() {
        let batch = OfferingBatch(serviceDate: serviceDate)
        context.insert(batch)

        for value in WeeklyReportImportParser.billValues {
            if let count = Int(denominations[value] ?? ""), count > 0,
               let denomination = BillDenomination(rawValue: value) {
                batch.setCount(count, for: denomination)
            }
        }

        for item in contributions {
            guard let cents = Money.parseCents(item.amount), cents > 0 else { continue }
            let entry = DonationEntry(
                amountCents: cents,
                method: item.isCheck ? .check : .envelopeCash,
                checkNumber: item.isCheck && !item.checkNumber.isEmpty ? item.checkNumber : nil,
                envelopeNumber: nil
            )
            context.insert(entry)
            if batch.entries == nil { batch.entries = [] }
            batch.entries?.append(entry)
            let name = item.name.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty,
               let donor = DonorResolver.resolveOrCreate(name: name, existing: donors, context: context) {
                if donor.donations == nil { donor.donations = [] }
                donor.donations?.append(entry)
            }
        }

        for item in expenses {
            guard let cents = Money.parseCents(item.amount), cents > 0 else { continue }
            let expense = ExpenseEntry(
                date: serviceDate,
                payee: item.paidTo.trimmingCharacters(in: .whitespaces),
                amountCents: cents,
                method: .cash,
                note: item.note.isEmpty ? nil : item.note
            )
            context.insert(expense)
            expense.paidFromBatch = batch
            if batch.cashReimbursements == nil { batch.cashReimbursements = [] }
            batch.cashReimbursements?.append(expense)
        }

        try? context.save()
        dismiss()
    }
}
