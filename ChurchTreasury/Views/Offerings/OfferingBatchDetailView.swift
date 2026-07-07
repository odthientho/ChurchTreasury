import SwiftUI
import SwiftData
import PhotosUI
import VisionKit

/// Read-oriented summary of one collection: status/details up top, then the
/// totals breakdown, then the itemized entries. New entries are added via
/// the Offerings list's quick buttons, not from this screen.
///
/// Once a collection is marked Deposited (money physically left for the
/// bank), its date/note/entries are locked against casual edits — reverting
/// the status back to Open requires confirmation, since that's the only way
/// to unlock it again.
struct OfferingBatchDetailView: View {
    @Bindable var batch: OfferingBatch
    @Environment(\.modelContext) private var context
    @Query(sort: \Donor.name) private var donors: [Donor]
    @State private var pendingStatus: BatchStatus?
    @State private var confirmingStatusChange = false
    @State private var editingEntry: DonationEntry?
    @State private var editingLooseCash = false
    @State private var addingReimbursement = false
    @State private var editingReimbursement: ExpenseEntry?
    // Collapsible breakdowns inside the totals section (closed by default).
    @State private var showCashBreakdown = false
    @State private var showReimbursementDetail = false
    @State private var showingWeeklyReport = false
    @State private var promptingDepositReceipt = false
    @State private var showingDepositCamera = false
    @State private var showingDepositPicker = false
    @State private var depositPickerItem: PhotosPickerItem?

    private var sortedEntries: [DonationEntry] {
        (batch.entries ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedReimbursements: [ExpenseEntry] {
        (batch.cashReimbursements ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    /// Locked once the money has left for the bank — only reverting the
    /// status (with confirmation) unlocks editing again.
    private var isLocked: Bool {
        batch.status != .open
    }

    private var statusBinding: Binding<BatchStatus> {
        Binding(
            get: { batch.status },
            set: { newValue in
                if batch.status == .deposited, newValue != .deposited {
                    pendingStatus = newValue
                    confirmingStatusChange = true
                } else {
                    let wasOpen = batch.status == .open
                    batch.status = newValue
                    try? context.save()
                    // Just deposited → offer to attach the bank receipt now.
                    if wasOpen, newValue == .deposited {
                        promptingDepositReceipt = true
                    }
                }
            }
        )
    }

    var body: some View {
        List {
            detailsSection
            totalsSection
            entriesSection
        }
        .navigationTitle(batch.serviceDate.formatted(.dateTime.month().day().year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingWeeklyReport = true
                } label: {
                    Label(String(localized: "report.weeklyExport"),
                          systemImage: "printer")
                }
            }
        }
        .sheet(isPresented: $showingWeeklyReport) {
            WeeklyReportPreviewSheet(batch: batch)
        }
        .alert(String(localized: "batch.confirmStatusChange.title"), isPresented: $confirmingStatusChange) {
            Button(String(localized: "action.cancel"), role: .cancel) {
                pendingStatus = nil
            }
            Button(String(localized: "action.changeAnyway"), role: .destructive) {
                if let pendingStatus {
                    batch.status = pendingStatus
                    try? context.save()
                }
                pendingStatus = nil
            }
        } message: {
            Text(String(localized: "batch.confirmStatusChange.message"))
        }
        // Prompt to attach the bank receipt right when the collection is
        // deposited — or skip it (Cancel) if there's no receipt yet.
        .confirmationDialog(String(localized: "offering.depositReceipt"),
                            isPresented: $promptingDepositReceipt, titleVisibility: .visible) {
            if VNDocumentCameraViewController.isSupported {
                Button(String(localized: "scan.takePhoto")) { showingDepositCamera = true }
            }
            Button(String(localized: "scan.chooseLibrary")) { showingDepositPicker = true }
            Button(String(localized: "action.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "offering.depositReceipt.prompt"))
        }
        .fullScreenCover(isPresented: $showingDepositCamera) {
            DocumentScannerView(
                onCapture: { image in showingDepositCamera = false; saveDepositReceipt(image) },
                onCancel: { showingDepositCamera = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingDepositPicker, selection: $depositPickerItem,
                      matching: .images)
        .onChange(of: depositPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    saveDepositReceipt(image)
                }
                depositPickerItem = nil
            }
        }
        .sheet(item: $editingEntry) { entry in
            EditDonationEntrySheet(entry: entry, donors: donors)
        }
        .sheet(isPresented: $editingLooseCash) {
            LooseCashSheet(initialDate: batch.serviceDate)
        }
        .sheet(isPresented: $addingReimbursement) {
            ExpenseFormView(expense: nil, paidFromBatch: batch)
        }
        .sheet(item: $editingReimbursement) { reimbursement in
            ExpenseFormView(expense: reimbursement)
        }
        .onDisappear {
            // Safety net for direct edits in detailsSection (service date,
            // note) — @Query views elsewhere shouldn't show stale data
            // after leaving this screen.
            try? context.save()
        }
    }

    private func saveDepositReceipt(_ image: UIImage) {
        if let old = batch.depositReceiptImageFilename {
            AttachmentStore.delete(old, from: .depositReceipts)
        }
        batch.depositReceiptImageFilename = AttachmentStore.compressed(image)
            .flatMap { AttachmentStore.save($0, in: .depositReceipts) }
        try? context.save()
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section {
            DatePicker(
                String(localized: "offering.serviceDate"),
                selection: $batch.serviceDate,
                displayedComponents: .date
            )
            .disabled(isLocked)

            if batch.status != .reconciled {
                Picker(String(localized: "batch.status"), selection: statusBinding) {
                    Text(BatchStatus.open.localizedName).tag(BatchStatus.open)
                    Text(BatchStatus.deposited.localizedName).tag(BatchStatus.deposited)
                }
            } else {
                LabeledContent(String(localized: "batch.status"),
                               value: BatchStatus.reconciled.localizedName)
            }

            TextField(
                String(localized: "field.note"),
                text: Binding(
                    get: { batch.note ?? "" },
                    set: { batch.note = $0.isEmpty ? nil : $0 }
                )
            )
            .disabled(isLocked)
        } footer: {
            if isLocked {
                Text(String(localized: "batch.lockedFooter"))
            }
        }
    }

    @ViewBuilder
    private var totalsSection: some View {
        Section {
            totalRow("offering.checks",
                     count: (batch.entries ?? []).count(where: { $0.method == .check }),
                     cents: batch.checksCents)

            // "Cash" = all cash received (envelope cash + loose plate cash).
            // Black text like the Checks row; taps to expand/collapse the
            // breakdown rather than to edit.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCashBreakdown.toggle() }
            } label: {
                HStack {
                    Text(String(localized: "offering.cash"))
                    disclosureChevron(showCashBreakdown)
                    Spacer()
                    Text(Money.format(batch.looseCashCents)).monospacedDigit()
                }
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showCashBreakdown {
                if batch.envelopeCashCents > 0 {
                    subRow("offering.envelopeCash", cents: batch.envelopeCashCents)
                }
                let loose = batch.looseCashCents - batch.envelopeCashCents
                if loose != 0 {
                    // The plate/loose cash is the editable count (tap to fix it).
                    subRow("offering.looseCash", cents: loose,
                           action: isLocked ? nil : { editingLooseCash = true })
                }
            }

            // The day's real income (gross, before any cash paid out).
            HStack {
                Text(String(localized: "offering.total")).font(.headline)
                Spacer()
                Text(Money.format(batch.totalCents)).font(.headline.monospacedDigit())
            }

            // Cash reimbursements — real expenses paid straight from the
            // collection. Expandable to view/add/edit each one; deducted from
            // the bank deposit. Shown whenever there are any, or when editable.
            if batch.cashReimbursementsCents > 0 || !isLocked {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showReimbursementDetail.toggle() }
                } label: {
                    HStack {
                        Text(String(localized: "offering.reimbursements"))
                        disclosureChevron(showReimbursementDetail)
                        Spacer()
                        if batch.cashReimbursementsCents > 0 {
                            Text("−" + Money.format(batch.cashReimbursementsCents))
                                .monospacedDigit()
                                .foregroundStyle(.red)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if showReimbursementDetail {
                ForEach(sortedReimbursements) { reimbursement in
                    Button {
                        editingReimbursement = reimbursement
                    } label: {
                        HStack {
                            Text(reimbursement.payee.isEmpty
                                 ? String(localized: "expense.payee") : reimbursement.payee)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("−" + Money.format(reimbursement.amountCents))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                }
                .onDelete(perform: reimbursementDeleteAction)

                if !isLocked {
                    Button {
                        addingReimbursement = true
                    } label: {
                        Label(String(localized: "offering.addReimbursement"), systemImage: "plus.circle")
                            .padding(.leading, 16)
                    }
                }
            }

            // What actually reached the bank after cash reimbursements.
            if batch.cashReimbursementsCents > 0 {
                HStack {
                    Text(String(localized: "offering.deposit"))
                    Spacer()
                    Text(Money.format(batch.netDepositCents))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text(String(localized: "offering.looseCashNote"))
        }
    }

    private func disclosureChevron(_ expanded: Bool) -> some View {
        Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    /// An indented breakdown line (no leading bullet). When `action` is
    /// non-nil the whole row is tappable and shows a trailing chevron.
    @ViewBuilder
    private func subRow(_ key: String, cents: Int, action: (() -> Void)? = nil) -> some View {
        let row = HStack {
            Text(String(localized: String.LocalizationValue(key)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(Money.format(cents))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 16)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private func totalRow(_ key: String, count: Int?, cents: Int, showsChevron: Bool = false) -> some View {
        HStack {
            Text(String(localized: String.LocalizationValue(key)))
            if let count, count > 0 {
                Text("(\(count))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money.format(cents))
                .monospacedDigit()
            if showsChevron, !isLocked {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    private var deleteAction: ((IndexSet) -> Void)? {
        if isLocked {
            return nil
        }
        return { offsets in deleteEntries(at: offsets) }
    }

    @ViewBuilder
    private var entriesSection: some View {
        if !sortedEntries.isEmpty {
            Section {
                ForEach(sortedEntries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        DonationEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                }
                .onDelete(perform: deleteAction)
            } header: {
                Text(String(localized: "offering.entries"))
            } footer: {
                if isLocked {
                    Text(String(localized: "batch.lockedFooter"))
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = sortedEntries[index]
            if let filename = entry.checkImageFilename {
                AttachmentStore.delete(filename, from: .offeringPhotos)
            }
            context.delete(entry)
        }
        try? context.save()
    }

    private var reimbursementDeleteAction: ((IndexSet) -> Void)? {
        if isLocked {
            return nil
        }
        return { offsets in deleteReimbursements(at: offsets) }
    }

    private func deleteReimbursements(at offsets: IndexSet) {
        for index in offsets {
            let reimbursement = sortedReimbursements[index]
            reimbursement.deleteAttachments()
            context.delete(reimbursement)
        }
        try? context.save()
    }
}
