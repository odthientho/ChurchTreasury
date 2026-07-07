import SwiftUI
import PhotosUI
import SwiftData
import VisionKit

/// Entry screen for one collection method (checks or envelope cash): the
/// date is right at the top (defaults to the most recent Sunday, editable
/// for catch-up entries), the manual quick-entry form is ready to type into
/// immediately, and scanning is offered as a secondary shortcut below it.
/// Reused for both methods; `method` just changes labels and which
/// DonationEntry field the number goes into.
struct CheckScanSheet: View {
    let donors: [Donor]
    var method: DonationMethod = .check

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \OfferingBatch.serviceDate) private var allBatches: [OfferingBatch]

    @State private var selectedDate = Date().previousSunday
    @State private var resolutionState: BatchResolutionState = .willCreate
    @State private var lockedCandidate: OfferingBatch?
    @State private var showingDepositedChoice = false

    @State private var showingCamera = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var capturedImage: UIImage?
    @State private var analysis: CheckImageAnalyzer.Analysis?
    @State private var photoLoadError: String?

    @State private var donorText = ""
    @State private var selectedDonor: Donor?
    @State private var numberText = ""
    @State private var amountText = ""
    @State private var addedEntries: [DonationEntry] = []
    @State private var editingEntry: DonationEntry?
    @FocusState private var focusedField: EntryField?

    enum EntryField {
        case donor, number, amount
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(method == .check
                    ? String(localized: "offering.checks")
                    : String(localized: "offering.envelopes"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.done")) { dismiss() }
                    }
                }
        }
        .sheet(item: $editingEntry) { entry in
            EditDonationEntrySheet(entry: entry, donors: donors)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            DocumentScannerView(
                onCapture: { image in
                    showingCamera = false
                    capturedImage = image
                    Task { await runAnalysis(image) }
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            // Unlike the camera button, PhotosPicker's selection can't
            // guard synchronously before presenting — materialize the
            // batch here instead, otherwise `content` never matches (it
            // requires a ready batch) and the picked photo silently does
            // nothing once `resolutionState` is still `.willCreate`.
            guard ensureBatch() != nil else { return }
            // Show the spinner right away — loading/decoding the picked
            // photo (esp. one still in iCloud) can take a few seconds on
            // its own, before OCR even starts. Without this, the screen
            // sits on the plain form for that whole stretch and looks
            // exactly like the picker did nothing.
            isAnalyzing = true
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data)
                    else {
                        isAnalyzing = false
                        photoLoadError = String(localized: "scan.photoLoadFailed")
                        return
                    }
                    capturedImage = image
                    await runAnalysis(image)
                } catch {
                    isAnalyzing = false
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
        .onAppear { resolveBatch() }
        .onChange(of: selectedDate) {
            addedEntries = []
            resolveBatch()
        }
        .confirmationDialog(
            String(localized: "batch.dateDeposited.title"),
            isPresented: $showingDepositedChoice,
            titleVisibility: .visible
        ) {
            Button(String(localized: "batch.addToExisting")) {
                if let lockedCandidate {
                    // Adding new money to it means it's no longer fully
                    // deposited — reopen it so the addition (and its
                    // existing entries) are shown and editable normally.
                    lockedCandidate.status = .open
                    try? context.save()
                    setReady(lockedCandidate)
                }
                lockedCandidate = nil
            }
            Button(String(localized: "batch.createSeparate")) {
                let batch = OfferingBatch(serviceDate: selectedDate)
                context.insert(batch)
                try? context.save()
                setReady(batch)
                lockedCandidate = nil
            }
            Button(String(localized: "action.cancel"), role: .cancel) {
                lockedCandidate = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let capturedImage, let analysis, let reviewBatch = resolutionState.readyBatch {
            CheckReviewView(image: capturedImage, analysis: analysis, batch: reviewBatch,
                            donors: donors, method: method) { entry in
                // Land back on this same Checks/Envelopes screen with the
                // scanned entry now in the "added this session" list, ready
                // for the next one — matching how manual Add behaves,
                // instead of closing the whole sheet.
                addedEntries.append(entry)
                self.capturedImage = nil
                self.analysis = nil
                photoPickerItem = nil
            }
        } else {
            // Overlay the spinner rather than swapping `manualAndScanForm`
            // out of the tree while analyzing — removing the PhotosPicker
            // (embedded in the form) mid-flight, while the system picker's
            // own dismissal transition is still resolving, corrupts the
            // presentation stack and dismisses this whole sheet along with
            // it. Keeping the form mounted the entire time sidesteps that.
            manualAndScanForm
                .overlay {
                    if isAnalyzing {
                        ZStack {
                            Color(.systemBackground).opacity(0.8)
                            ProgressView(String(localized: "scan.processing"))
                        }
                        .ignoresSafeArea()
                    }
                }
                .disabled(isAnalyzing)
        }
    }

    private var manualAndScanForm: some View {
        Form {
            Section {
                DatePicker(String(localized: "offering.serviceDate"), selection: $selectedDate,
                          displayedComponents: .date)
            }

            Section {
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

                HStack {
                    TextField(
                        method == .check
                            ? String(localized: "field.checkNumber")
                            : String(localized: "field.envelopeNumber"),
                        text: $numberText
                    )
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .number)

                    Divider()

                    TextField(String(localized: "field.amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .amount)
                }

                Button {
                    addEntry()
                } label: {
                    Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(resolutionState.isAwaitingChoice || Money.parseCents(amountText) == nil)
            }

            Section(String(localized: "scan.orScanPhoto")) {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        guard ensureBatch() != nil else { return }
                        showingCamera = true
                    } label: {
                        Label(String(localized: "scan.takePhoto"), systemImage: "doc.viewfinder")
                    }
                    .disabled(resolutionState.isAwaitingChoice)
                }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label(String(localized: "scan.chooseLibrary"), systemImage: "photo.on.rectangle")
                }
                .disabled(resolutionState.isAwaitingChoice)
            }

            if !addedEntries.isEmpty {
                Section(String(localized: "offering.entries")) {
                    ForEach(addedEntries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            DonationEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteEntries)
                    HStack {
                        Text(String(localized: "offering.total")).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(Money.format(addedEntries.reduce(0) { $0 + $1.amountCents }))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "action.done")) { focusedField = nil }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusedField = .donor }
        }
    }

    // MARK: - Batch resolution

    /// Re-evaluates which batch the selected date should target — an
    /// existing open one, a lazily-created new one, or (if every collection
    /// for that day is already deposited) a choice the treasurer must make.
    private func resolveBatch() {
        switch BatchDateResolver.resolve(date: selectedDate, among: allBatches) {
        case .useExisting(let batch):
            setReady(batch)
        case .createNew:
            resolutionState = .willCreate
        case .needsDepositedChoice(let locked):
            resolutionState = .needsChoice(locked)
            lockedCandidate = locked
            showingDepositedChoice = true
        }
    }

    /// Materializes the target batch, creating it on first use so that
    /// scrubbing the date picker doesn't leave behind empty batches.
    private func ensureBatch() -> OfferingBatch? {
        switch resolutionState {
        case .ready(let batch):
            return batch
        case .willCreate:
            let batch = OfferingBatch(serviceDate: selectedDate)
            context.insert(batch)
            try? context.save()
            setReady(batch)
            return batch
        case .needsChoice:
            return nil
        }
    }

    /// Marks the batch ready and loads whatever entries of this method it
    /// already has — otherwise resuming a collection (e.g. via "Add to That
    /// Collection" on a deposited day) would hide checks/envelopes already
    /// recorded, instead of showing the full list to review and correct.
    private func setReady(_ batch: OfferingBatch) {
        resolutionState = .ready(batch)
        addedEntries = (batch.entries ?? [])
            .filter { $0.method == method }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Actions

    private func addEntry() {
        guard let batch = ensureBatch() else { return }
        guard let cents = Money.parseCents(amountText), cents > 0 else { return }

        let donor = resolveDonor()
        let entry = DonationEntry(
            amountCents: cents,
            method: method,
            checkNumber: method == .check && !numberText.isEmpty ? numberText : nil,
            envelopeNumber: method == .envelopeCash && !numberText.isEmpty ? numberText : nil
        )
        context.insert(entry)
        // Append to the forward relationship arrays, not just the inverse —
        // SwiftData's Observation tracking keys off the array being mutated,
        // so setting only the inverse leaves other views' reads of
        // batch.entries / donor.donations stale after this sheet closes.
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
        addedEntries.append(entry)

        donorText = ""
        selectedDonor = nil
        numberText = ""
        amountText = ""
        focusedField = .donor
    }

    private func resolveDonor() -> Donor? {
        if let selectedDonor { return selectedDonor }
        return DonorResolver.resolveOrCreate(name: donorText, existing: donors, context: context)
    }

    /// Lets the treasurer correct a mis-entered check/envelope by removing
    /// it here — the app's established way to "update" an entry, matching
    /// how OfferingBatchDetailView handles corrections elsewhere.
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = addedEntries[index]
            if let filename = entry.checkImageFilename {
                AttachmentStore.delete(filename, from: .offeringPhotos)
            }
            context.delete(entry)
        }
        addedEntries.remove(atOffsets: offsets)
        try? context.save()
    }

    private func runAnalysis(_ image: UIImage) async {
        isAnalyzing = true
        analysis = await CheckImageAnalyzer.analyze(image)
        isAnalyzing = false
    }
}
