import SwiftUI
import SwiftData
import PhotosUI
import VisionKit

/// Edits an existing check or envelope entry's donor, number, and amount.
/// Reused everywhere entries are listed (the check-scan session list and the
/// batch detail view) so a mis-entered value can be fixed in place instead
/// of deleting and re-adding.
struct EditDonationEntrySheet: View {
    let entry: DonationEntry
    let donors: [Donor]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var donorText: String
    @State private var selectedDonor: Donor?
    @State private var numberText: String
    @State private var amountText: String
    @State private var checkImage: UIImage?
    @State private var pendingImageData: Data?
    @State private var showingCamera = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoLoadError: String?
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case donor, number, amount
    }

    init(entry: DonationEntry, donors: [Donor]) {
        self.entry = entry
        self.donors = donors
        _donorText = State(initialValue: entry.donor?.name ?? "")
        _selectedDonor = State(initialValue: entry.donor)
        _numberText = State(initialValue: entry.method == .check
            ? (entry.checkNumber ?? "")
            : (entry.envelopeNumber ?? ""))
        _amountText = State(initialValue: Money.formatPlain(entry.amountCents)
            .replacingOccurrences(of: ",", with: ""))
    }

    var body: some View {
        NavigationStack {
            Form {
                DonorAutocompleteField(
                    text: $donorText,
                    selectedDonor: $selectedDonor,
                    donors: donors,
                    focus: $focusedField,
                    focusValue: .donor,
                    onSelect: { _ in focusedField = .number }
                )

                TextField(
                    entry.method == .check
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

                if let checkImage {
                    Section(String(localized: "scan.photo")) {
                        Image(uiImage: checkImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .listRowBackground(Color.clear)
                } else {
                    // Manually-entered checks/envelopes have no photo yet —
                    // offer the same capture/upload options the scan flow
                    // uses, so one can be attached after the fact.
                    Section(String(localized: "scan.photo")) {
                        if VNDocumentCameraViewController.isSupported {
                            Button {
                                showingCamera = true
                            } label: {
                                Label(String(localized: "scan.takePhoto"), systemImage: "doc.viewfinder")
                            }
                        }
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            Label(String(localized: "scan.chooseLibrary"), systemImage: "photo.on.rectangle")
                        }
                    }
                    .disabled(isLoadingPhoto)
                }
            }
            .navigationTitle(entry.method == .check
                ? String(localized: "scan.editCheck")
                : String(localized: "scan.editEnvelope"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                        .disabled((Money.parseCents(amountText) ?? 0) <= 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "action.done")) { focusedField = nil }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                DocumentScannerView(
                    onCapture: { image in
                        showingCamera = false
                        checkImage = image
                        pendingImageData = AttachmentStore.compressed(image)
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
            }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                isLoadingPhoto = true
                Task {
                    do {
                        guard let data = try await newItem.loadTransferable(type: Data.self),
                              let image = UIImage(data: data)
                        else {
                            isLoadingPhoto = false
                            photoLoadError = String(localized: "scan.photoLoadFailed")
                            return
                        }
                        checkImage = image
                        pendingImageData = AttachmentStore.compressed(image)
                        isLoadingPhoto = false
                    } catch {
                        isLoadingPhoto = false
                        photoLoadError = String(localized: "scan.photoLoadFailed")
                    }
                    photoPickerItem = nil
                }
            }
            .alert(
                String(localized: "scan.photoLoadFailedTitle"),
                isPresented: Binding(get: { photoLoadError != nil }, set: { if !$0 { photoLoadError = nil } }),
                presenting: photoLoadError
            ) { _ in
                Button(String(localized: "action.done"), role: .cancel) { photoLoadError = nil }
            } message: { message in
                Text(message)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusedField = .donor }
                if let filename = entry.checkImageFilename {
                    checkImage = AttachmentStore.load(filename, from: .offeringPhotos)
                }
            }
        }
    }

    private func save() {
        guard let cents = Money.parseCents(amountText), cents > 0 else { return }
        let donor = selectedDonor ?? DonorResolver.resolveOrCreate(name: donorText, existing: donors, context: context)

        if entry.donor !== donor {
            // Mutate the forward array on both sides, not just `entry.donor`
            // — SwiftData Observation keys off the forward collection being
            // mutated (see the app-wide relationship-append convention).
            entry.donor?.donations?.removeAll { $0 === entry }
            entry.donor = donor
            if let donor {
                if donor.donations == nil { donor.donations = [] }
                donor.donations?.append(entry)
            }
        }

        if let pendingImageData {
            entry.checkImageFilename = AttachmentStore.save(pendingImageData, in: .offeringPhotos)
        }

        entry.amountCents = cents
        switch entry.method {
        case .check:
            entry.checkNumber = numberText.isEmpty ? nil : numberText
        case .envelopeCash:
            entry.envelopeNumber = numberText.isEmpty ? nil : numberText
            if entry.donor?.envelopeNumber == nil, !numberText.isEmpty {
                entry.donor?.envelopeNumber = numberText
            }
        }
        try? context.save()
        dismiss()
    }
}
