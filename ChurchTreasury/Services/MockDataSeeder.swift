#if DEBUG
import Foundation
import SwiftData

/// Fills the app with a realistic, comprehensive demo dataset for screenshots
/// and the promo video. Triggered only by the `-seedMockData` launch argument
/// (DEBUG builds only), it wipes any existing data first so every run starts
/// from the same clean, curated state.
enum MockDataSeeder {
    @MainActor
    static func seedIfRequested(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedMockData") else { return }

        wipe(context)
        seedSettings()
        CategorySeeder.seedIfNeeded(context: context)

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        func cat(_ key: String) -> Category? { categories.first { $0.builtinKey == key } }

        let donors = seedDonors(context)
        seedRecurring(context, cat: cat)
        seedOfferings(context, donors: donors, cat: cat)
        seedExpenses(context, cat: cat)
        seedReimbursements(context)

        try? context.save()
    }

    // MARK: Wipe

    @MainActor
    private static func wipe(_ context: ModelContext) {
        for type in [DonationEntry.self] { try? context.delete(model: type) }
        try? context.delete(model: BankTransaction.self)
        try? context.delete(model: BankStatementImport.self)
        try? context.delete(model: ReconciliationPeriod.self)
        try? context.delete(model: ReimbursementRequest.self)
        try? context.delete(model: ExpenseEntry.self)
        try? context.delete(model: OfferingBatch.self)
        try? context.delete(model: RecurringExpense.self)
        try? context.delete(model: Donor.self)
        try? context.delete(model: Category.self)
        try? context.save()
    }

    // MARK: Settings

    private static func seedSettings() {
        let d = UserDefaults.standard
        // Fictional — deliberately not the real church this app was built
        // for, so demo builds/screenshots never surface real identifying info.
        d.set("Grace Fellowship Church", forKey: "churchName")
        d.set("100 Fellowship Way, Alpharetta, GA 30022", forKey: "churchAddress")
        d.set("Alex Tran", forKey: "treasurerName")
        d.set(1_850_000, forKey: "netAssetAnchorCents")   // $18,500.00
        d.set(date(2026, 4, 1).timeIntervalSince1970, forKey: "netAssetAnchorMonth")
    }

    // MARK: Donors

    @MainActor
    private static func seedDonors(_ context: ModelContext) -> [Donor] {
        let specs: [(name: String, env: String, real: String?, addr: String?, phone: String?)] = [
            ("Nguyễn Văn An", "101", "An V. Nguyen", "312 Oak Ridge Dr, Lilburn, GA 30047", "770-555-0112"),
            ("Trần Thị Bích", "102", "Bich T. Tran", "88 Rockbridge Rd, Stone Mountain, GA 30083", "678-555-0143"),
            ("Lê Hoàng Nam", "103", "Nam H. Le", "455 Killian Hill Rd, Lilburn, GA 30047", "404-555-0187"),
            ("Phạm Minh Đức", "104", "Duc M. Pham", "27 Pleasant Hill Rd, Duluth, GA 30096", "770-555-0166"),
            ("Võ Thị Lan", "105", "Lan T. Vo", "910 Beaver Ruin Rd, Norcross, GA 30093", "678-555-0198"),
            ("Hoàng Đức Thắng", "106", "Thang D. Hoang", "144 Indian Trail Rd, Norcross, GA 30093", nil),
            ("Đặng Kim Yến", "107", "Yen K. Dang", "76 Singleton Rd, Norcross, GA 30093", "470-555-0121"),
            ("Bùi Thanh Sơn", "108", nil, "500 Club Dr, Lawrenceville, GA 30044", "770-555-0154"),
            ("John Smith", "109", "John A. Smith", "215 Sugarloaf Pkwy, Lawrenceville, GA 30045", "678-555-0177"),
            ("Mary Tran", "110", "Mary Tran", "63 Ronald Reagan Blvd, Lawrenceville, GA 30044", "404-555-0133"),
            ("Ngô Quang Huy", "111", "Huy Q. Ngo", "801 Pirkle Ferry Rd, Cumming, GA 30040", nil),
            ("Đỗ Ngọc Hà", "112", "Ha N. Do", "19 Steve Reynolds Blvd, Duluth, GA 30096", "770-555-0190"),
        ]
        var donors: [Donor] = []
        for spec in specs {
            let donor = Donor(name: spec.name, envelopeNumber: spec.env,
                              address: spec.addr, phone: spec.phone)
            donor.realName = spec.real
            context.insert(donor)
            donors.append(donor)
        }
        // A gathered alias so the "combine duplicates" story is visible.
        donors[4].aliases = ["Vo Thi Lan", "Lan Vo"]
        return donors
    }

    // MARK: Recurring templates

    @MainActor
    private static func seedRecurring(_ context: ModelContext, cat: (String) -> Category?) {
        let specs: [(payee: String, detail: String, method: ExpensePaymentMethod?, catKey: String, i: Int)] = [
            ("Senior Pastor", "Senior Pastor Allowance", .check, "cat.expense.salary", 0),
            ("Associate Pastor", "Associate Pastor Allowance", .check, "cat.expense.salary", 1),
            ("Georgia Power", "Electricity", .online, "cat.expense.utilities", 2),
            ("Gwinnett County Water", "Water & Sewer", .online, "cat.expense.utilities", 3),
            ("Comcast Business", "Internet & Phone", .zelle, "cat.expense.utilities", 4),
            ("C&MA National Office", "Denominational Contribution", .check, "cat.expense.missions", 5),
            ("GreenLawn Services", "Lawn Care", .cash, "cat.expense.maintenance", 6),
            ("Church Mutual", "Property Insurance", .check, "cat.expense.insurance", 7),
        ]
        for spec in specs {
            let template = RecurringExpense(payee: spec.payee, detail: spec.detail,
                                            method: spec.method, sortIndex: spec.i)
            context.insert(template)
            template.category = cat(spec.catKey)
        }
    }

    // MARK: Offerings

    @MainActor
    private static func seedOfferings(_ context: ModelContext, donors: [Donor],
                                      cat: (String) -> Category?) {
        // (Sundays, status) — older months settled, recent ones in progress.
        let months: [(sundays: [Date], status: BatchStatus)] = [
            ([date(2026, 4, 5), date(2026, 4, 12), date(2026, 4, 19), date(2026, 4, 26)], .reconciled),
            ([date(2026, 5, 3), date(2026, 5, 10), date(2026, 5, 17), date(2026, 5, 24), date(2026, 5, 31)], .reconciled),
            ([date(2026, 6, 7), date(2026, 6, 14), date(2026, 6, 21), date(2026, 6, 28)], .deposited),
            ([date(2026, 7, 5)], .open),
        ]
        let checkAmounts = [100, 150, 200, 250, 300, 400, 500]
        let envAmounts = [20, 30, 40, 50, 60, 100]
        var week = 0
        for month in months {
            for sunday in month.sundays {
                let batch = OfferingBatch(serviceDate: sunday)
                context.insert(batch)
                batch.status = month.status

                // 6 check gifts
                for j in 0..<6 {
                    let donor = donors[(week * 3 + j) % donors.count]
                    let amount = checkAmounts[(week + j) % checkAmounts.count] * 100
                    let entry = DonationEntry(amountCents: amount, method: .check,
                                              checkNumber: String(1200 + week * 7 + j))
                    context.insert(entry)
                    entry.donor = donor
                    batch.entries?.append(entry)
                    donor.donations?.append(entry)
                }
                // 4 envelope-cash gifts
                for j in 0..<4 {
                    let donor = donors[(week * 2 + j + 5) % donors.count]
                    let amount = envAmounts[(week + j) % envAmounts.count] * 100
                    let entry = DonationEntry(amountCents: amount, method: .envelopeCash,
                                              envelopeNumber: donor.envelopeNumber)
                    context.insert(entry)
                    entry.donor = donor
                    batch.entries?.append(entry)
                    donor.donations?.append(entry)
                }
                // Loose plate cash, counted by denomination
                batch.bills20Count = 3 + (week % 4)
                batch.bills10Count = 5 + (week % 3)
                batch.bills5Count = 4 + (week % 2)
                batch.bills1Count = 12 + (week % 9)
                week += 1

                // One cash reimbursement paid straight from a June collection.
                if sunday == date(2026, 6, 28) {
                    let reimb = ExpenseEntry(date: sunday, payee: "Võ Thị Lan",
                                             amountCents: 4_250, method: .cash,
                                             note: "Communion cups & bread")
                    context.insert(reimb)
                    reimb.category = cat("cat.expense.supplies")
                    reimb.paidFromBatch = batch
                    batch.cashReimbursements?.append(reimb)
                }
            }
        }
    }

    // MARK: Expenses

    @MainActor
    private static func seedExpenses(_ context: ModelContext, cat: (String) -> Category?) {
        let templates = (try? context.fetch(FetchDescriptor<RecurringExpense>())) ?? []
        func add(_ date: Date, _ payee: String, _ cents: Int, _ method: ExpensePaymentMethod,
                 _ catKey: String, regular: Bool, check: String? = nil, note: String? = nil) {
            let expense = ExpenseEntry(date: date, payee: payee, amountCents: cents,
                                       method: method, checkNumber: check, note: note)
            context.insert(expense)
            expense.isRegular = regular
            expense.category = cat(catKey)
            // Link a regular expense to its recurring template so the monthly
            // checklist correctly shows it as already recorded.
            if regular, let template = templates.first(where: { $0.payee == payee }) {
                expense.recurringTemplate = template
                if template.expenses == nil { template.expenses = [] }
                template.expenses?.append(expense)
            }
        }

        // Regular monthly expenses for April, May, June (July left partly open
        // so the monthly checklist demo has items still to record).
        for (month, checkBase) in [(4, 2401), (5, 2431), (6, 2461)] {
            add(date(2026, month, 1), "Senior Pastor", 300_000, .check, "cat.expense.salary",
                regular: true, check: String(checkBase))
            add(date(2026, month, 1), "Associate Pastor", 150_000, .check, "cat.expense.salary",
                regular: true, check: String(checkBase + 1))
            add(date(2026, month, 8), "Georgia Power", 21_840 + month * 100, .online,
                "cat.expense.utilities", regular: true, note: "Electricity")
            add(date(2026, month, 8), "Gwinnett County Water", 8_675, .online,
                "cat.expense.utilities", regular: true, note: "Water & Sewer")
            add(date(2026, month, 10), "Comcast Business", 12_999, .zelle,
                "cat.expense.utilities", regular: true, note: "Internet & Phone")
            add(date(2026, month, 15), "C&MA National Office", 60_000, .check,
                "cat.expense.missions", regular: true, check: String(checkBase + 2))
            add(date(2026, month, 20), "GreenLawn Services", 12_000, .cash,
                "cat.expense.maintenance", regular: true, note: "Lawn Care")
            add(date(2026, month, 5), "Church Mutual", 41_000, .check, "cat.expense.insurance",
                regular: true, check: String(checkBase + 3))
        }

        // A couple of July regulars already recorded (rest still pending).
        add(date(2026, 7, 1), "Senior Pastor", 300_000, .check, "cat.expense.salary",
            regular: true, check: "2491")
        add(date(2026, 7, 1), "Associate Pastor", 150_000, .check, "cat.expense.salary",
            regular: true, check: "2492")

        // Special (one-off) expenses across the months.
        add(date(2026, 4, 12), "LifeWay Christian", 9_540, .online, "cat.expense.supplies",
            regular: false, note: "Sunday School curriculum")
        add(date(2026, 4, 26), "Gwinnett Benevolence Fund", 30_000, .check, "cat.expense.benevolence",
            regular: false, check: "2410", note: "Family assistance — Tran household")
        add(date(2026, 5, 17), "Camp Highland", 50_000, .check, "cat.expense.missions",
            regular: false, check: "2440", note: "Youth summer camp deposit")
        add(date(2026, 5, 24), "ABC Paving", 85_000, .check, "cat.expense.maintenance",
            regular: false, check: "2441", note: "Parking lot crack repair")
        add(date(2026, 6, 14), "Rev. Daniel Pham", 25_000, .zelle, "cat.expense.other",
            regular: false, note: "Guest speaker honorarium")
        add(date(2026, 6, 21), "Costco Wholesale", 18_760, .online, "cat.expense.supplies",
            regular: false, note: "Fellowship lunch supplies")
    }

    // MARK: Reimbursement requests (pending)

    @MainActor
    private static func seedReimbursements(_ context: ModelContext) {
        let a = ReimbursementRequest(person: "Đặng Kim Yến", detail: "Nursery supplies",
                                     amountCents: 4_520,
                                     dateRequested: date(2026, 7, 2))
        context.insert(a)
        let b = ReimbursementRequest(person: "Phạm Minh Đức", detail: "Youth event snacks",
                                     amountCents: 7_850,
                                     dateRequested: date(2026, 6, 29))
        context.insert(b)
    }

    // MARK: Helpers

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
#endif
