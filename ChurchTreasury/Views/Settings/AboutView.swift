import Foundation

// In-app help: concise question-and-answer topics covering every feature,
// shown as expandable accordions in the "About" section of the More tab.

struct HelpTopic: Identifiable {
    let id = UUID()
    let icon: String
    let question: String
    let answer: String
}

enum HelpContent {
    static let topics: [HelpTopic] = [
        HelpTopic(icon: "sparkles", question: "What does this app do?", answer: """
        Everything a church treasurer needs, on your phone: record Sunday offerings, track expenses, reconcile the bank, and make reports (weekly, monthly, year-end, giving statements, and an audit packet). Use the tabs below.
        """),
        HelpTopic(icon: "lock.shield", question: "Is my data private? Where is it kept?", answer: """
        Everything stays on this phone only — nothing goes to the cloud. It's in Files → On My iPhone → Church Treasury, together with every photo you scan.
        """),
        HelpTopic(icon: "globe", question: "Vietnamese and name matching", answer: """
        The app follows your phone's language. Donor names match across accents, so "Nguyen" finds "Nguyễn."
        """),
        HelpTopic(icon: "heart.circle.fill", question: "How do I record a Sunday offering?", answer: """
        Offerings tab → Checks, Envelopes, or Loose Cash.
        • Checks are itemized per donor.
        • Loose Cash is the total cash, counted by bill.
        • Envelopes just record which donor gave cash (for their giving statement) — that cash is already inside the loose-cash total, so it's never counted twice.
        Deposit total = checks + loose cash.
        """),
        HelpTopic(icon: "arrow.uturn.left", question: "We paid someone from the offering plate", answer: """
        Open the collection → Add Cash Reimbursement. It's subtracted from the deposit and still recorded as a cash expense.
        """),
        HelpTopic(icon: "checkmark.seal", question: "Marking a collection deposited", answer: """
        Open it and set Status to Deposited. You'll be asked to scan the bank receipt (or skip it). Once deposited, it locks against accidental edits.
        """),
        HelpTopic(icon: "doc.viewfinder", question: "Scanning checks and importing a paper report", answer: """
        When adding a check or envelope, tap Scan to read the name, amount, and check number automatically.
        To enter a whole paper weekly report at once, tap the scan icon next to the Offerings title, scan the page, review the lines, and Import.
        """),
        HelpTopic(icon: "person.2.fill", question: "Donor nicknames vs. real names", answer: """
        The name you type is your own shorthand. For the tax-receipt giving statement, open the donor and add their "Real name" — only that legal name prints on the statement.
        """),
        HelpTopic(icon: "arrow.triangle.merge", question: "Combining duplicate donors", answer: """
        More → Donors → the merge button. Pick the names that are the same person and keep one (or type a new one). The other spellings become searchable aliases so future imports find them.
        """),
        HelpTopic(icon: "creditcard.fill", question: "Recording an expense", answer: """
        Expenses tab → Check, Online, or Cash (Zelle is in the form). Add the payee, amount, category, and note, and attach a scanned receipt. Regular expenses recur monthly; Special are one-offs.
        """),
        HelpTopic(icon: "checklist", question: "Recording the monthly 'Regular' expenses", answer: """
        Set up recurring items once in More → Regular Expenses. Each month, tap the checklist icon on the Expenses title — it shows what's recorded and what's still missing; tap Add and enter this month's amount.
        """),
        HelpTopic(icon: "hand.raised.fill", question: "Reimbursement requests", answer: """
        Tap the raised-hand icon on the Expenses title to log money someone spent for the church before you pay them (scan their receipt). It shows a "Pending" badge. Tap it to pay — it becomes a "Paid" expense. Swipe to edit or delete.
        """),
        HelpTopic(icon: "building.columns.fill", question: "Reconciling with the bank", answer: """
        Reports → Monthly Treasurer Report → the bank icon. Import your bank statement; anything on it that isn't in your records yet, you add as income or expense so your books match the bank.
        """),
        HelpTopic(icon: "doc.richtext", question: "What reports can I make?", answer: """
        In the Reports tab: Weekly (one collection), Monthly Treasurer (Operation Fund), Annual Giving Statements (tax receipts), Year in Review (big-font slides for the projector), and the Annual Audit Report (full ledgers plus every scanned receipt in one printable PDF).
        """),
        HelpTopic(icon: "square.and.arrow.up", question: "Backup and handing off to the next treasurer", answer: """
        Your records and photos live in Files → On My iPhone → Church Treasury. Share or AirDrop that folder to back it up or to hand everything to the next treasurer.
        """),
    ]
}
