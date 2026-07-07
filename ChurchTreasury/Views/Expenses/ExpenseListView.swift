import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExpenseEntry.date, order: .reverse) private var expenses: [ExpenseEntry]
    @Query(sort: \ReimbursementRequest.dateRequested, order: .reverse)
    private var requests: [ReimbursementRequest]
    @State private var editingExpense: ExpenseEntry?
    @State private var entryMethod: ExpensePaymentMethod?
    @State private var addingRequest = false
    @State private var editingRequest: ReimbursementRequest?
    @State private var payingRequest: ReimbursementRequest?
    @State private var showingRegularChecklist = false

    /// Reimbursement requests not yet paid back — shown regardless of month.
    private var pendingRequests: [ReimbursementRequest] {
        requests.filter { !$0.isPaid }
    }
    // Default to the month of the current collection Sunday (matching the new
    // expenses date to that same Sunday) so a freshly-recorded expense is
    // visible under the default filter — see OfferingListView for the rationale.
    @State private var selectedMonth: Date = Date().previousSunday.startOfMonth

    /// Expenses that fall within the currently-filtered month, newest first
    /// (the @Query already sorts by date descending).
    private var monthExpenses: [ExpenseEntry] {
        expenses.filter {
            Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var monthTotal: Int {
        monthExpenses.reduce(0) { $0 + $1.amountCents }
    }

    var body: some View {
        NavigationStack {
            List {
                if monthItems.isEmpty {
                    ContentUnavailableView(
                        selectedMonth.monthYearLabel,
                        systemImage: "creditcard",
                        description: Text(String(localized: "expenses.monthEmpty"))
                    )
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(monthItems) { item in
                            row(for: item)
                        }
                    } header: {
                        HStack {
                            Text(selectedMonth.monthYearLabel)
                            Spacer()
                            Text(Money.format(monthTotal))
                                .monospacedDigit()
                        }
                    }
                }
            }
            // Fixed header (title + quick buttons + month filter) pinned above
            // the list, so only the expense list itself scrolls.
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    header
                    quickEntryRow
                        .padding(.horizontal)
                    MonthFilterBar(month: $selectedMonth)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
                .background(Color(.systemGroupedBackground))
            }
            // Title drawn in-content (see `header`) to match the Offerings
            // tab's position; the bar is hidden but the title stays set so
            // pushed views keep a proper "‹ Expenses" back button.
            .navigationTitle(String(localized: "tab.expenses"))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $entryMethod) { method in
                ExpenseEntrySheet(method: method)
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseFormView(expense: expense)
            }
            .sheet(isPresented: $addingRequest) {
                ReimbursementRequestFormView(request: nil)
            }
            .sheet(item: $editingRequest) { request in
                ReimbursementRequestFormView(request: request)
            }
            .sheet(item: $payingRequest) { request in
                ExpenseFormView(expense: nil, reimbursementRequest: request)
            }
            .sheet(isPresented: $showingRegularChecklist) {
                MonthlyExpenseChecklistView(month: selectedMonth)
            }
        }
    }

    /// One row in the month list: either a recorded expense (already paid) or a
    /// still-pending reimbursement request.
    private enum Item: Identifiable {
        case expense(ExpenseEntry)
        case pendingRequest(ReimbursementRequest)

        var id: PersistentIdentifier {
            switch self {
            case .expense(let e): e.persistentModelID
            case .pendingRequest(let r): r.persistentModelID
            }
        }
        var date: Date {
            switch self {
            case .expense(let e): e.date
            case .pendingRequest(let r): r.dateRequested
            }
        }
    }

    /// The month's expenses plus any still-pending reimbursement requests dated
    /// in that month, newest first — so the list is "normal", just with pending
    /// items mixed in and badged.
    private var monthItems: [Item] {
        let expenseItems = monthExpenses.map(Item.expense)
        let requestItems = pendingRequests
            .filter { Calendar.current.isDate($0.dateRequested, equalTo: selectedMonth, toGranularity: .month) }
            .map(Item.pendingRequest)
        return (expenseItems + requestItems).sorted { $0.date > $1.date }
    }

    @ViewBuilder
    private func row(for item: Item) -> some View {
        switch item {
        case .expense(let expense):
            Button {
                editingExpense = expense
            } label: {
                ExpenseRow(expense: expense)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    delete(expense)
                } label: {
                    Label(String(localized: "action.delete"), systemImage: "trash")
                }
            }
        case .pendingRequest(let request):
            Button {
                // Tap a pending request = pay it back now.
                payingRequest = request
            } label: {
                ReimbursementRow(request: request)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .leading) {    // swipe left→right = edit
                Button {
                    editingRequest = request
                } label: {
                    Label(String(localized: "action.edit"), systemImage: "pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {   // swipe right→left = delete
                Button(role: .destructive) {
                    delete(request)
                } label: {
                    Label(String(localized: "action.delete"), systemImage: "trash")
                }
            }
        }
    }

    // Screen title drawn in-content, with the "request reimbursement" action
    // sitting right next to it (like the Offerings tab's scan button).
    private var header: some View {
        HStack(spacing: 10) {
            Text(String(localized: "tab.expenses"))
                .font(.largeTitle.bold())
            Button {
                addingRequest = true
            } label: {
                Image(systemName: "hand.raised")
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "reimburse.add"))
            Spacer()
            // Record the month's recurring "Regular" expenses (allowances,
            // utilities, contributions) — treasurer does these at month start.
            Button {
                showingRegularChecklist = true
            } label: {
                Image(systemName: "checklist")
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "expense.addRegular"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var quickEntryRow: some View {
        HStack(spacing: 10) {
            ExpenseQuickButton(
                titleKey: "expense.checks", systemImage: "pencil.and.list.clipboard", color: .blue
            ) { entryMethod = .check }
            ExpenseQuickButton(
                titleKey: "expense.online", systemImage: "creditcard.fill", color: .indigo
            ) { entryMethod = .online }
            ExpenseQuickButton(
                titleKey: "expense.cash", systemImage: "banknote.fill", color: .green
            ) { entryMethod = .cash }
        }
        .padding(.vertical, 4)
    }

    private func delete(_ expense: ExpenseEntry) {
        expense.deleteAttachments()
        context.delete(expense)
        try? context.save()
    }

    private func delete(_ request: ReimbursementRequest) {
        request.deleteAttachments()
        context.delete(request)
        try? context.save()
    }
}

/// A small status pill, e.g. "Pending" (orange) or "Paid" (green).
private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct ReimbursementRow: View {
    let request: ReimbursementRequest

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.person)
                HStack(spacing: 4) {
                    Text(request.dateRequested, format: .dateTime.month().day())
                    if !request.detail.isEmpty {
                        Text("· \(request.detail)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(text: String(localized: "status.pending"), color: .orange)
            if request.receiptImageFilename != nil {
                Image(systemName: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(Money.format(request.amountCents))
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

private struct ExpenseQuickButton: View {
    let titleKey: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(String(localized: String.LocalizationValue(titleKey)))
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: String.LocalizationValue(titleKey)))
    }
}

private struct ExpenseRow: View {
    let expense: ExpenseEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.payee)
                HStack(spacing: 4) {
                    Text(expense.date, format: .dateTime.month().day())
                    Text("· \(expense.method.localizedName)")
                    if let category = expense.category {
                        Text("· \(category.displayName)")
                    }
                    if let check = expense.checkNumber, !check.isEmpty {
                        Text("· #\(check)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            // A "Paid" pill marks expenses that paid off a reimbursement
            // request, so the request's pending→paid transition is visible.
            if expense.reimbursementRequest != nil {
                StatusPill(text: String(localized: "status.paid"), color: .green)
            }
            if expense.receiptImageFilename != nil || expense.checkImageFilename != nil {
                Image(systemName: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(Money.format(expense.amountCents))
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}
