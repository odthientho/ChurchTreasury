import UIKit

/// The weekly contribution report the treasurer keeps as a physical record.
/// Laid out to match the church's existing paper form: a numbered contribution
/// list on the left; income summary, cash-denomination breakdown, cash
/// expenses, and signature lines on the right.
///
/// Labels are intentionally in English to match the standardized paper form.
enum WeeklyContributionReportPDF {

    // MARK: - Data

    struct Data_: Sendable {
        struct Contribution: Sendable {
            var name: String
            var checkAmountCents: Int?
            var checkNumber: String?
            var cashAmountCents: Int?
        }
        struct Denomination: Sendable {
            var dollar: Int
            var count: Int
            var amountCents: Int
        }
        struct Expense: Sendable {
            var paidTo: String
            var detail: String
            var amountCents: Int
        }

        var churchName: String = ""
        var logoPNG: Foundation.Data?
        var date: Date = .now
        var week: Int = 0
        var checkIncomeCents = 0
        var cashIncomeCents = 0
        var totalIncomeCents = 0
        var cashExpensesCents = 0
        var bankDepositCents = 0
        var contributions: [Contribution] = []
        var denominations: [Denomination] = []
        var expenses: [Expense] = []
    }

    /// Builds the report from a saved collection. `@MainActor` because it reads
    /// SwiftData model relationships.
    @MainActor
    static func data(for batch: OfferingBatch, churchName: String,
                     logoPNG: Foundation.Data? = nil) -> Data_ {
        let contributions = (batch.entries ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .map { entry -> Data_.Contribution in
                let name = entry.donor?.name ?? String(localized: "donor.anonymous")
                if entry.method == .check {
                    return .init(name: name, checkAmountCents: entry.amountCents,
                                 checkNumber: entry.checkNumber, cashAmountCents: nil)
                }
                return .init(name: name, checkAmountCents: nil, checkNumber: nil,
                             cashAmountCents: entry.amountCents)
            }

        let denominations = BillDenomination.allCases.map { denomination -> Data_.Denomination in
            let count = batch.count(for: denomination)
            return .init(dollar: denomination.rawValue, count: count,
                         amountCents: denomination.rawValue * count * 100)
        }

        let expenses = (batch.cashReimbursements ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .map { expense -> Data_.Expense in
                .init(paidTo: expense.payee,
                      detail: expense.note ?? "",
                      amountCents: expense.amountCents)
            }

        return Data_(
            churchName: churchName,
            logoPNG: logoPNG,
            date: batch.serviceDate,
            week: weekOfMonth(batch.serviceDate),
            checkIncomeCents: batch.checksCents,
            cashIncomeCents: batch.looseCashCents,
            totalIncomeCents: batch.totalCents,
            cashExpensesCents: batch.cashReimbursementsCents,
            bankDepositCents: batch.netDepositCents,
            contributions: contributions,
            denominations: denominations,
            expenses: expenses
        )
    }

    /// The Nth occurrence of the collection's weekday within its month
    /// (e.g. the 4th Sunday → week 4), matching the paper form's "Week" field.
    static func weekOfMonth(_ date: Date) -> Int {
        let day = Calendar.current.component(.day, from: date)
        return (day - 1) / 7 + 1
    }

    // MARK: - Rendering

    private static let pageSize = CGSize(width: 612, height: 792)   // US Letter
    private static let margin: CGFloat = 24

    @MainActor
    static func render(_ data: Data_) -> Foundation.Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let painter = Painter(cg: ctx.cgContext)
            layout(data, painter)
        }
    }

    // MARK: - Layout

    @MainActor
    private static func layout(_ data: Data_, _ p: Painter) {
        let left = margin
        let right = pageSize.width - margin

        // Church logo (top-left corner), if imported. The title stays centered
        // across the full width, so a small mark on the left doesn't collide.
        if let logo = data.logoPNG {
            p.image(logo, in: CGRect(x: left, y: 16, width: 52, height: 52))
        }

        // Title.
        p.text("WEEKLY CONTRIBUTION REPORT",
               in: CGRect(x: left, y: 22, width: right - left, height: 24),
               font: .boldSystemFont(ofSize: 15), align: .center)
        if !data.churchName.isEmpty {
            p.text(data.churchName,
                   in: CGRect(x: left, y: 44, width: right - left, height: 14),
                   font: .systemFont(ofSize: 10), align: .center, color: .darkGray)
        }

        // Date / Week box (top-left).
        let dwY: CGFloat = 68, rowH: CGFloat = 22, labelW: CGFloat = 96, valueW: CGFloat = 84
        p.cell(CGRect(x: left, y: dwY, width: labelW, height: rowH), "Date", bold: true)
        p.cell(CGRect(x: left + labelW, y: dwY, width: valueW, height: rowH), Self.dateString(data.date))
        p.cell(CGRect(x: left, y: dwY + rowH, width: labelW, height: rowH), "Week", bold: true)
        p.cell(CGRect(x: left + labelW, y: dwY + rowH, width: valueW, height: rowH), "\(data.week)")

        // Income summary (top-right). Starts well clear of the contribution
        // list (which ends at ~308) so the two columns don't touch.
        let sumX: CGFloat = 330, sumLabelW: CGFloat = 132, sumValueW: CGFloat = 126, sumRowH: CGFloat = 22
        let summary: [(String, String, Bool)] = [
            ("Check Income", Money.format(data.checkIncomeCents), false),
            ("Cash Income", Money.format(data.cashIncomeCents), false),
            ("Total of Income", Money.format(data.totalIncomeCents), true),
            ("Cash Expenses", data.cashExpensesCents > 0 ? "(" + Money.format(data.cashExpensesCents) + ")" : "", false),
            ("Bank Deposit", Money.format(data.bankDepositCents), true),
        ]
        for (index, row) in summary.enumerated() {
            let y = 60 + CGFloat(index) * sumRowH
            p.text(row.0, in: CGRect(x: sumX, y: y, width: sumLabelW, height: sumRowH),
                   font: row.2 ? .boldSystemFont(ofSize: 10) : .systemFont(ofSize: 10),
                   align: .right, vInset: 4)
            p.cell(CGRect(x: sumX + sumLabelW, y: y, width: sumValueW, height: sumRowH),
                   row.1, align: .right, bold: row.2)
        }

        layoutContributionList(data, p, x: left, topY: 120, bottomY: pageSize.height - margin)
        layoutRightColumn(data, p, x: sumX, topY: 180, bottomY: pageSize.height - margin, width: right - sumX)
    }

    @MainActor
    private static func layoutContributionList(_ data: Data_, _ p: Painter,
                                               x: CGFloat, topY: CGFloat, bottomY: CGFloat) {
        // Total width 284 (ends at x≈308) — kept narrow so it clears the
        // right-hand column that starts at x=330.
        let numW: CGFloat = 24, nameW: CGFloat = 130, ckAmtW: CGFloat = 48, ckNoW: CGFloat = 36, cashW: CGFloat = 46
        let tableW = numW + nameW + ckAmtW + ckNoW + cashW

        p.text("Contribution List", in: CGRect(x: x, y: topY, width: tableW, height: 16),
               font: .boldSystemFont(ofSize: 10), align: .left)

        // Two-row header: #, NAME span both rows; CHECK spans two sub-columns.
        let h1 = topY + 18, r1: CGFloat = 20, r2: CGFloat = 16
        let headerH = r1 + r2
        p.cell(CGRect(x: x, y: h1, width: numW, height: headerH), "#", bold: true)
        p.cell(CGRect(x: x + numW, y: h1, width: nameW, height: headerH), "NAME", bold: true)
        let ckX = x + numW + nameW
        p.cell(CGRect(x: ckX, y: h1, width: ckAmtW + ckNoW, height: r1), "CHECK", bold: true)
        p.cell(CGRect(x: ckX, y: h1 + r1, width: ckAmtW, height: r2), "Amount", bold: true)
        p.cell(CGRect(x: ckX + ckAmtW, y: h1 + r1, width: ckNoW, height: r2), "CH #", bold: true)
        let cashX = ckX + ckAmtW + ckNoW
        p.cell(CGRect(x: cashX, y: h1, width: cashW, height: r1), "CASH", bold: true)
        p.cell(CGRect(x: cashX, y: h1 + r1, width: cashW, height: r2), "Amount", bold: true)

        // Data rows: at least ~34 for a form feel, more if there are more
        // entries; height shrinks to keep everything on one page.
        let dataTop = h1 + headerH
        let available = bottomY - dataTop
        let minRows = 34
        let rowCount = max(minRows, data.contributions.count)
        let dataRowH = min(15, max(10, available / CGFloat(rowCount)))

        let numberFont = UIFont.systemFont(ofSize: 8)
        for i in 0..<rowCount {
            let y = dataTop + CGFloat(i) * dataRowH
            let contribution = i < data.contributions.count ? data.contributions[i] : nil
            p.cell(CGRect(x: x, y: y, width: numW, height: dataRowH), "\(i + 1)", font: numberFont)
            p.cell(CGRect(x: x + numW, y: y, width: nameW, height: dataRowH),
                   contribution?.name ?? "", align: .left, font: numberFont)
            p.cell(CGRect(x: ckX, y: y, width: ckAmtW, height: dataRowH),
                   contribution?.checkAmountCents.map { Money.formatPlain($0) } ?? "",
                   align: .right, font: numberFont)
            p.cell(CGRect(x: ckX + ckAmtW, y: y, width: ckNoW, height: dataRowH),
                   contribution?.checkNumber ?? "", font: numberFont)
            p.cell(CGRect(x: cashX, y: y, width: cashW, height: dataRowH),
                   contribution?.cashAmountCents.map { Money.formatPlain($0) } ?? "",
                   align: .right, font: numberFont)
        }
    }

    @MainActor
    private static func layoutRightColumn(_ data: Data_, _ p: Painter,
                                          x: CGFloat, topY: CGFloat, bottomY: CGFloat, width: CGFloat) {
        var y = topY

        // CASH INCOME.
        p.text("CASH INCOME", in: CGRect(x: x, y: y, width: width, height: 16),
               font: .boldSystemFont(ofSize: 11), align: .left)
        y += 18
        let dollarW: CGFloat = 60, countW: CGFloat = 44, amtW = width - 60 - 44
        let ciRowH: CGFloat = 18
        p.cell(CGRect(x: x, y: y, width: dollarW, height: ciRowH), "Dollar", bold: true)
        p.cell(CGRect(x: x + dollarW, y: y, width: countW, height: ciRowH), "#", bold: true)
        p.cell(CGRect(x: x + dollarW + countW, y: y, width: amtW, height: ciRowH), "Amount", bold: true)
        y += ciRowH
        for denomination in data.denominations {
            p.cell(CGRect(x: x, y: y, width: dollarW, height: ciRowH), "$\(denomination.dollar)")
            p.cell(CGRect(x: x + dollarW, y: y, width: countW, height: ciRowH), "\(denomination.count)")
            p.cell(CGRect(x: x + dollarW + countW, y: y, width: amtW, height: ciRowH),
                   Money.format(denomination.amountCents), align: .right)
            y += ciRowH
        }

        // CASH EXPENSE.
        y += 20
        p.text("CASH EXPENSE", in: CGRect(x: x, y: y, width: width, height: 16),
               font: .boldSystemFont(ofSize: 11), align: .left)
        y += 18
        let paidW: CGFloat = 68, detailW: CGFloat = 96, expAmtW = width - 68 - 96
        let ceRowH: CGFloat = 18
        p.cell(CGRect(x: x, y: y, width: paidW, height: ceRowH), "Paid To", bold: true)
        p.cell(CGRect(x: x + paidW, y: y, width: detailW, height: ceRowH), "Description", bold: true)
        p.cell(CGRect(x: x + paidW + detailW, y: y, width: expAmtW, height: ceRowH), "Amount", bold: true)
        y += ceRowH
        let expenseRows = max(5, data.expenses.count)
        for i in 0..<expenseRows {
            let expense = i < data.expenses.count ? data.expenses[i] : nil
            p.cell(CGRect(x: x, y: y, width: paidW, height: ceRowH), expense?.paidTo ?? "", align: .left)
            p.cell(CGRect(x: x + paidW, y: y, width: detailW, height: ceRowH), expense?.detail ?? "", align: .left)
            p.cell(CGRect(x: x + paidW + detailW, y: y, width: expAmtW, height: ceRowH),
                   expense.map { "(" + Money.format($0.amountCents) + ")" } ?? "", align: .right)
            y += ceRowH
        }

        // Verified By.
        y += 24
        let labelW: CGFloat = 78, sigW: CGFloat = 90, nameW = width - 78 - 90
        let vRowH: CGFloat = 28
        p.cell(CGRect(x: x, y: y, width: labelW, height: 18), "", border: false)
        p.cell(CGRect(x: x + labelW, y: y, width: sigW, height: 18), "Signature", bold: true)
        p.cell(CGRect(x: x + labelW + sigW, y: y, width: nameW, height: 18), "Name", bold: true)
        y += 18
        for _ in 0..<5 {
            p.cell(CGRect(x: x, y: y, width: labelW, height: vRowH), "Verified By", align: .left, bold: true)
            p.cell(CGRect(x: x + labelW, y: y, width: sigW, height: vRowH), "")
            p.cell(CGRect(x: x + labelW + sigW, y: y, width: nameW, height: vRowH), "")
            y += vRowH
        }
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: date)
    }

    // MARK: - Drawing primitive

    private final class Painter {
        let cg: CGContext
        init(cg: CGContext) { self.cg = cg }

        /// Draws a bordered cell with vertically-centered text.
        func cell(_ rect: CGRect, _ string: String,
                  align: NSTextAlignment = .center, bold: Bool = false,
                  font: UIFont? = nil, border: Bool = true, color: UIColor = .black) {
            if border {
                cg.setStrokeColor(UIColor.black.cgColor)
                cg.setLineWidth(0.75)
                cg.stroke(rect)
            }
            guard !string.isEmpty else { return }
            let f = font ?? (bold ? UIFont.boldSystemFont(ofSize: 9) : UIFont.systemFont(ofSize: 9))
            drawText(string, in: rect.insetBy(dx: 3, dy: 0), font: f, align: align, color: color)
        }

        /// Draws an image fit within `rect` (aspect-preserving, centered).
        func image(_ data: Foundation.Data, in rect: CGRect) {
            guard let image = UIImage(data: data),
                  image.size.width > 0, image.size.height > 0 else { return }
            let fit = min(rect.width / image.size.width, rect.height / image.size.height)
            let w = image.size.width * fit
            let h = image.size.height * fit
            image.draw(in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
        }

        /// Draws borderless text within a rect (vertically centered).
        func text(_ string: String, in rect: CGRect, font: UIFont,
                  align: NSTextAlignment = .left, color: UIColor = .black, vInset: CGFloat = 0) {
            drawText(string, in: rect.insetBy(dx: vInset, dy: 0), font: font, align: align, color: color)
        }

        private func drawText(_ string: String, in rect: CGRect, font: UIFont,
                              align: NSTextAlignment, color: UIColor) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = align
            paragraph.lineBreakMode = .byTruncatingTail
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
            ]
            let textHeight = font.lineHeight
            let y = rect.origin.y + (rect.height - textHeight) / 2
            let drawRect = CGRect(x: rect.origin.x, y: y, width: rect.width, height: textHeight)
            (string as NSString).draw(in: drawRect, withAttributes: attributes)
        }
    }
}
