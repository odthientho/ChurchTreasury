import Foundation

/// Value-type report models plus the pure aggregation that fills them, so
/// report totals are testable without rendering PDFs.

struct ChurchInfo: Sendable {
    var name = ""
    var address = ""
    var treasurerName = ""
    /// Optional imported church logo (PNG bytes) drawn atop the reports.
    var logoPNG: Data?
}

/// The Operation Fund monthly report, matching the church's spreadsheet: a
/// weekly deposit table (deposit + cash-expense = contribution), Regular and
/// Special expense sections, and a net-asset summary that carries forward.
struct MonthlyReportData: Sendable {
    struct IncomeRow: Sendable {
        var serviceDate: Date
        var eventName: String
        var depositCents: Int        // money actually banked
        var cashExpenseCents: Int    // cash reimbursed straight from the collection
        var contributionCents: Int   // gross = deposit + cash expense
    }

    struct ExpenseRow: Sendable {
        var date: Date
        var typeName: String         // Check / Online / Zelle / Cash
        var detail: String           // description
        var payee: String            // paid to
        var amountCents: Int
    }

    var church = ChurchInfo()
    var month: Date = .now
    var incomeRows: [IncomeRow] = []
    var regularExpenseRows: [ExpenseRow] = []
    var specialExpenseRows: [ExpenseRow] = []
    var beginningNetAssetCents = 0
    /// Regular expenses on file that weren't recorded this month (a heads-up).
    var missingRegularNames: [String] = []

    var depositTotalCents: Int { incomeRows.reduce(0) { $0 + $1.depositCents } }
    var cashExpenseTotalCents: Int { incomeRows.reduce(0) { $0 + $1.cashExpenseCents } }
    var incomeTotalCents: Int { incomeRows.reduce(0) { $0 + $1.contributionCents } }
    var regularExpenseTotalCents: Int { regularExpenseRows.reduce(0) { $0 + $1.amountCents } }
    var specialExpenseTotalCents: Int { specialExpenseRows.reduce(0) { $0 + $1.amountCents } }
    var expenseTotalCents: Int { regularExpenseTotalCents + specialExpenseTotalCents }
    var earningLossCents: Int { incomeTotalCents - expenseTotalCents }
    var endingNetAssetCents: Int { beginningNetAssetCents + earningLossCents }
}

struct GivingStatementData: Sendable {
    struct Row: Sendable {
        var date: Date
        var methodName: String
        var checkNumber: String?
        var amountCents: Int
    }

    var church = ChurchInfo()
    var year: Int
    var donorName = ""
    var donorAddress: String?
    var rows: [Row] = []

    var totalCents: Int { rows.reduce(0) { $0 + $1.amountCents } }
}

/// A full year of aggregated figures for the year-end presentation (charts,
/// big numbers) and the year-end audit report (full ledgers + evidence).
struct AnnualReportData: Sendable {
    struct MonthPoint: Sendable { var month: Int; var incomeCents: Int; var expenseCents: Int }
    struct NamedTotal: Sendable { var name: String; var cents: Int }
    struct IncomeRow: Sendable {
        var date: Date; var checksCents: Int; var cashCents: Int
        var totalCents: Int; var depositCents: Int; var status: String
    }
    struct ExpenseRow: Sendable {
        var date: Date; var typeName: String; var detail: String
        var payee: String; var checkNumber: String?; var amountCents: Int
    }
    /// A photo attached somewhere in the year, to embed as audit evidence.
    struct Evidence: Sendable {
        var filename: String
        var folder: AttachmentStore.Folder
        var caption: String
        var date: Date
    }

    var church = ChurchInfo()
    var year: Int
    var months: [MonthPoint] = []
    var incomeTotalCents = 0
    var expenseTotalCents = 0
    var regularExpenseCents = 0
    var specialExpenseCents = 0
    var beginningNetAssetCents = 0
    var expenseCategories: [NamedTotal] = []
    var donorCount = 0
    var givingTotalCents = 0
    var incomeRows: [IncomeRow] = []
    var expenseRows: [ExpenseRow] = []
    var evidence: [Evidence] = []

    var earningLossCents: Int { incomeTotalCents - expenseTotalCents }
    var endingNetAssetCents: Int { beginningNetAssetCents + earningLossCents }
    var averageMonthlyIncomeCents: Int { incomeTotalCents / 12 }
    var averageMonthlyExpenseCents: Int { expenseTotalCents / 12 }
    var peakIncomeMonth: MonthPoint? { months.max { $0.incomeCents < $1.incomeCents } }
    var peakExpenseMonth: MonthPoint? { months.max { $0.expenseCents < $1.expenseCents } }
}

enum ReportDataBuilder {

    @MainActor
    static func monthlyReport(month: Date,
                              church: ChurchInfo,
                              batches: [OfferingBatch],
                              expenses: [ExpenseEntry],
                              recurring: [RecurringExpense] = [],
                              netAssetAnchorCents: Int = 0,
                              netAssetAnchorMonth: Date? = nil) -> MonthlyReportData {
        let monthStart = month.startOfMonth
        let nextMonthStart = month.startOfNextMonth

        let monthBatches = batches
            .filter { $0.serviceDate >= monthStart && $0.serviceDate < nextMonthStart }
            .sorted { $0.serviceDate < $1.serviceDate }
        let monthExpenses = expenses
            .filter { $0.date >= monthStart && $0.date < nextMonthStart }
            .sorted { $0.date < $1.date }

        var data = MonthlyReportData()
        data.church = church
        data.month = monthStart

        // Beginning Net Asset carries forward: the anchor balance plus every
        // month's (contribution − expense) from the anchor month up to this one.
        let anchorStart = netAssetAnchorMonth?.startOfMonth ?? .distantPast
        let priorIncome = batches
            .filter { $0.serviceDate >= anchorStart && $0.serviceDate < monthStart }
            .reduce(0) { $0 + $1.totalCents }
        let priorExpense = expenses
            .filter { $0.date >= anchorStart && $0.date < monthStart }
            .reduce(0) { $0 + $1.amountCents }
        data.beginningNetAssetCents = netAssetAnchorCents + priorIncome - priorExpense

        let sundayService = String(localized: "report.sundayService")
        data.incomeRows = monthBatches.map {
            .init(serviceDate: $0.serviceDate,
                  eventName: sundayService,
                  depositCents: $0.netDepositCents,
                  cashExpenseCents: $0.cashReimbursementsCents,
                  contributionCents: $0.totalCents)
        }

        func row(_ e: ExpenseEntry) -> MonthlyReportData.ExpenseRow {
            // Description column = the expense's note (not its category).
            .init(date: e.date,
                  typeName: e.method.localizedName,
                  detail: e.note ?? "",
                  payee: e.payee,
                  amountCents: e.amountCents)
        }
        data.regularExpenseRows = monthExpenses.filter { $0.isRegular }.map(row)
        data.specialExpenseRows = monthExpenses.filter { !$0.isRegular }.map(row)

        // Regular expenses on file that haven't been recorded this month.
        data.missingRegularNames = recurring
            .filter { !$0.isRecorded(inMonthOf: month) }
            .map { $0.detail.isEmpty ? $0.payee : $0.detail }

        return data
    }

    /// One statement per donor who gave anything in the year, sorted by name.
    @MainActor
    static func givingStatements(year: Int,
                                 church: ChurchInfo,
                                 donors: [Donor]) -> [GivingStatementData] {
        donors.compactMap { donor -> GivingStatementData? in
            let rows = (donor.donations ?? [])
                .compactMap { entry -> GivingStatementData.Row? in
                    guard let serviceDate = entry.batch?.serviceDate,
                          Calendar.current.component(.year, from: serviceDate) == year
                    else { return nil }
                    return .init(date: serviceDate,
                                 methodName: entry.method.localizedName,
                                 checkNumber: entry.checkNumber,
                                 amountCents: entry.amountCents)
                }
                .sorted { $0.date < $1.date }
            guard !rows.isEmpty else { return nil }

            var data = GivingStatementData(year: year)
            data.church = church
            // Tax receipt uses the donor's real/legal name (falls back to the
            // treasurer's shorthand name when no real name was entered).
            data.donorName = donor.legalName
            data.donorAddress = donor.address
            data.rows = rows
            return data
        }
        .sorted { $0.donorName.localizedCompare($1.donorName) == .orderedAscending }
    }

    @MainActor
    static func annualReport(year: Int,
                             church: ChurchInfo,
                             batches: [OfferingBatch],
                             expenses: [ExpenseEntry],
                             donors: [Donor],
                             netAssetAnchorCents: Int = 0,
                             netAssetAnchorMonth: Date? = nil) -> AnnualReportData {
        let cal = Calendar.current
        let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .now
        let yearEnd = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? .now

        let yBatches = batches
            .filter { $0.serviceDate >= yearStart && $0.serviceDate < yearEnd }
            .sorted { $0.serviceDate < $1.serviceDate }
        let yExpenses = expenses
            .filter { $0.date >= yearStart && $0.date < yearEnd }
            .sorted { $0.date < $1.date }

        var data = AnnualReportData(year: year)
        data.church = church

        var months = (1...12).map { AnnualReportData.MonthPoint(month: $0, incomeCents: 0, expenseCents: 0) }
        for b in yBatches { months[cal.component(.month, from: b.serviceDate) - 1].incomeCents += b.totalCents }
        for e in yExpenses { months[cal.component(.month, from: e.date) - 1].expenseCents += e.amountCents }
        data.months = months

        data.incomeTotalCents = yBatches.reduce(0) { $0 + $1.totalCents }
        data.expenseTotalCents = yExpenses.reduce(0) { $0 + $1.amountCents }
        data.regularExpenseCents = yExpenses.filter { $0.isRegular }.reduce(0) { $0 + $1.amountCents }
        data.specialExpenseCents = yExpenses.filter { !$0.isRegular }.reduce(0) { $0 + $1.amountCents }

        // Beginning net asset carries forward from the settings anchor.
        let anchorStart = netAssetAnchorMonth?.startOfMonth ?? .distantPast
        let priorIncome = batches
            .filter { $0.serviceDate >= anchorStart && $0.serviceDate < yearStart }
            .reduce(0) { $0 + $1.totalCents }
        let priorExpense = expenses
            .filter { $0.date >= anchorStart && $0.date < yearStart }
            .reduce(0) { $0 + $1.amountCents }
        data.beginningNetAssetCents = netAssetAnchorCents + priorIncome - priorExpense

        let noneName = String(localized: "expense.category.none")
        data.expenseCategories = Dictionary(grouping: yExpenses, by: { $0.category?.displayName ?? noneName })
            .map { .init(name: $0.key, cents: $0.value.reduce(0) { $0 + $1.amountCents }) }
            .sorted { $0.cents > $1.cents }

        func inYear(_ entry: DonationEntry) -> Bool {
            guard let sd = entry.batch?.serviceDate else { return false }
            return cal.component(.year, from: sd) == year
        }
        data.donorCount = donors.filter { d in (d.donations ?? []).contains { inYear($0) } }.count
        data.givingTotalCents = donors.reduce(0) { acc, d in
            acc + (d.donations ?? []).filter { inYear($0) }.reduce(0) { $0 + $1.amountCents }
        }

        data.incomeRows = yBatches.map {
            .init(date: $0.serviceDate, checksCents: $0.checksCents, cashCents: $0.looseCashCents,
                  totalCents: $0.totalCents, depositCents: $0.netDepositCents, status: $0.status.localizedName)
        }
        data.expenseRows = yExpenses.map {
            .init(date: $0.date, typeName: $0.method.localizedName, detail: $0.note ?? "",
                  payee: $0.payee, checkNumber: $0.checkNumber, amountCents: $0.amountCents)
        }

        // Evidence: every photo attached during the year, captioned for audit.
        func shortDate(_ date: Date) -> String { date.formatted(.dateTime.month().day().year()) }
        var evidence: [AnnualReportData.Evidence] = []
        for b in yBatches {
            if let f = b.depositReceiptImageFilename {
                evidence.append(.init(filename: f, folder: .depositReceipts,
                                      caption: String(format: String(localized: "audit.evidence.deposit"),
                                                      shortDate(b.serviceDate), Money.format(b.netDepositCents)),
                                      date: b.serviceDate))
            }
            for entry in (b.entries ?? []) where entry.checkImageFilename != nil {
                evidence.append(.init(filename: entry.checkImageFilename!, folder: .offeringPhotos,
                                      caption: String(format: String(localized: "audit.evidence.offering"),
                                                      shortDate(b.serviceDate), Money.format(entry.amountCents)),
                                      date: b.serviceDate))
            }
        }
        for e in yExpenses {
            if let f = e.receiptImageFilename {
                evidence.append(.init(filename: f, folder: .expenseReceipts,
                                      caption: String(format: String(localized: "audit.evidence.receipt"),
                                                      e.payee, Money.format(e.amountCents)),
                                      date: e.date))
            }
            if let f = e.checkImageFilename {
                evidence.append(.init(filename: f, folder: .expenseChecks,
                                      caption: String(format: String(localized: "audit.evidence.check"),
                                                      e.payee, Money.format(e.amountCents)),
                                      date: e.date))
            }
        }
        data.evidence = evidence.sorted { $0.date < $1.date }

        return data
    }
}
