import SwiftUI
import SwiftData

/// Shows the scanned check or envelope with its OCR'd fields pre-filled and
/// editable. Nothing is committed as a DonationEntry until the treasurer
/// taps Save — OCR is a starting guess, never a trusted value.
struct CheckReviewView: View {
    let image: UIImage
    let analysis: CheckImageAnalyzer.Analysis
    let batch: OfferingBatch
    let donors: [Donor]
    var method: DonationMethod = .check
    var onSave: (DonationEntry) -> Void

    @Environment(\.modelContext) private var context
    @State private var donorText = ""
    @State private var selectedDonor: Donor?
    @State private var numberText = ""
    @State private var amountText = ""
    @FocusState private var focusedField: FocusField?

    enum FocusField: Hashable {
        case donor, number, amount
    }

    var body: some View {
        Form {
            Section {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .listRowBackground(Color.clear)

            if !analysis.parsed.warnings.isEmpty {
                Section {
                    ForEach(analysis.parsed.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }
            }

            Section(String(localized: "scan.reviewFields")) {
                DonorAutocompleteField(
                    text: $donorText,
                    selectedDonor: $selectedDonor,
                    donors: donors,
                    focus: $focusedField,
                    focusValue: .donor,
                    onSelect: { donor in
                        if method == .envelopeCash, numberText.isEmpty {
                            numberText = donor.envelopeNumber ?? ""
                        }
                        focusedField = .number
                    }
                )

                TextField(
                    method == .check
                        ? String(localized: "field.checkNumber")
                        : String(localized: "field.envelopeNumber"),
                    text: $numberText
                )
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .number)

                HStack {
                    Text(String(localized: "field.amount"))
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                        .focused($focusedField, equals: .amount)
                }

                if method == .check, let checkDate = analysis.parsed.checkDate {
                    LabeledContent(String(localized: "scan.checkDate"),
                                   value: checkDate.formatted(.dateTime.month().day().year()))
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "action.save")) { save() }
                    .disabled((Money.parseCents(amountText) ?? 0) <= 0)
            }
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        donorText = analysis.parsed.payerName ?? ""
        if method == .check {
            numberText = analysis.parsed.checkNumber ?? ""
        }
        if let cents = analysis.parsed.amountCents {
            amountText = Money.formatPlain(cents).replacingOccurrences(of: ",", with: "")
        }
        if let name = analysis.parsed.payerName {
            selectedDonor = donors.first {
                $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
            if method == .envelopeCash, numberText.isEmpty {
                numberText = selectedDonor?.envelopeNumber ?? ""
            }
        }
    }

    private func save() {
        guard let cents = Money.parseCents(amountText), cents > 0 else { return }
        let donor = selectedDonor
            ?? DonorResolver.resolveOrCreate(name: donorText, existing: donors, context: context)

        let entry = DonationEntry(
            amountCents: cents,
            method: method,
            checkNumber: method == .check && !numberText.isEmpty ? numberText : nil,
            envelopeNumber: method == .envelopeCash && !numberText.isEmpty ? numberText : nil
        )
        context.insert(entry)
        if let data = analysis.storedImageData {
            entry.checkImageFilename = AttachmentStore.save(data, in: .offeringPhotos)
        }
        // Append to the forward relationship arrays, not just the inverse —
        // see OfferingBatchDetailView.addEntry for why this matters.
        if batch.entries == nil { batch.entries = [] }
        batch.entries?.append(entry)
        if let donor {
            if donor.donations == nil { donor.donations = [] }
            donor.donations?.append(entry)
            if method == .envelopeCash, donor.envelopeNumber == nil, !numberText.isEmpty {
                donor.envelopeNumber = numberText
            }
        }
        try? context.save()

        onSave(entry)
    }
}
