import SwiftUI
import SwiftData

/// Focused modal for counting loose cash by bill denomination — the sole
/// destination for the Loose Cash quick-entry button. The date is at the
/// top (defaults to the most recent Sunday, editable for catch-up entries);
/// the underlying batch is only created once a count is actually entered,
/// so scrubbing the date doesn't leave behind empty batches.
struct LooseCashSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \OfferingBatch.serviceDate) private var allBatches: [OfferingBatch]

    @State private var selectedDate: Date
    @State private var resolutionState: BatchResolutionState = .willCreate
    @State private var lockedCandidate: OfferingBatch?
    @State private var showingDepositedChoice = false
    @FocusState private var focusedBill: BillDenomination?

    init(initialDate: Date = Date().previousSunday) {
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(String(localized: "offering.serviceDate"), selection: $selectedDate,
                              displayedComponents: .date)
                }

                Section {
                    ForEach(BillDenomination.allCases) { denomination in
                        BillCountRow(
                            denomination: denomination,
                            count: countBinding(for: denomination),
                            focus: $focusedBill
                        )
                    }
                    .disabled(resolutionState.isAwaitingChoice)
                    HStack {
                        Text(String(localized: "offering.total"))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(Money.format(resolutionState.readyBatch?.looseCashCents ?? 0))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                }
            }
            .navigationTitle(String(localized: "offering.looseCash"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done")) {
                        try? context.save()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "action.done")) { focusedBill = nil }
                }
            }
            .onAppear {
                resolveBatch()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusedBill = .one }
            }
            .onChange(of: selectedDate) { resolveBatch() }
            .confirmationDialog(
                String(localized: "batch.dateDeposited.title"),
                isPresented: $showingDepositedChoice,
                titleVisibility: .visible
            ) {
                Button(String(localized: "batch.addToExisting")) {
                    if let lockedCandidate {
                        // Adding new money to it means it's no longer fully
                        // deposited — reopen it so the addition (and its
                        // existing counts) are shown and editable normally.
                        lockedCandidate.status = .open
                        try? context.save()
                        resolutionState = .ready(lockedCandidate)
                    }
                    lockedCandidate = nil
                }
                Button(String(localized: "batch.createSeparate")) {
                    let batch = OfferingBatch(serviceDate: selectedDate)
                    context.insert(batch)
                    try? context.save()
                    resolutionState = .ready(batch)
                    lockedCandidate = nil
                }
                Button(String(localized: "action.cancel"), role: .cancel) {
                    lockedCandidate = nil
                }
            }
        }
    }

    private func countBinding(for denomination: BillDenomination) -> Binding<Int> {
        Binding(
            get: { resolutionState.readyBatch?.count(for: denomination) ?? 0 },
            set: { newValue in
                ensureBatch()?.setCount(newValue, for: denomination)
            }
        )
    }

    // MARK: - Batch resolution

    private func resolveBatch() {
        switch BatchDateResolver.resolve(date: selectedDate, among: allBatches) {
        case .useExisting(let batch):
            resolutionState = .ready(batch)
        case .createNew:
            resolutionState = .willCreate
        case .needsDepositedChoice(let locked):
            resolutionState = .needsChoice(locked)
            lockedCandidate = locked
            showingDepositedChoice = true
        }
    }

    private func ensureBatch() -> OfferingBatch? {
        switch resolutionState {
        case .ready(let batch):
            return batch
        case .willCreate:
            let batch = OfferingBatch(serviceDate: selectedDate)
            context.insert(batch)
            try? context.save()
            resolutionState = .ready(batch)
            return batch
        case .needsChoice:
            return nil
        }
    }
}
