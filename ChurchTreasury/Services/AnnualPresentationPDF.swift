import UIKit

/// A landscape, projector-friendly "Year in Review" — big numbers, bar charts,
/// and trend comparisons meant to be shown on a screen at church. Deliberately
/// large fonts and high-contrast colors so it reads from the back of a room.
@MainActor
enum AnnualPresentationPDF {
    private static let pageSize = CGSize(width: 1024, height: 768)   // 4:3 slide
    private static let margin: CGFloat = 56

    private static let income = UIColor.systemGreen
    private static let expense = UIColor.systemRed
    private static let accent = UIColor(red: 0.15, green: 0.40, blue: 0.60, alpha: 1)
    private static let ink = UIColor.label

    static func render(_ data: AnnualReportData) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            coverSlide(ctx, data)
            headlineSlide(ctx, data)
            monthlyTrendSlide(ctx, data)
            categorySlide(ctx, data)
            highlightsSlide(ctx, data)
        }
    }

    // MARK: - Slides

    private static func coverSlide(_ ctx: UIGraphicsPDFRendererContext, _ data: AnnualReportData) {
        ctx.beginPage()
        let cg = ctx.cgContext
        accent.setFill()
        cg.fill(CGRect(x: 0, y: 0, width: pageSize.width, height: 12))
        cg.fill(CGRect(x: 0, y: pageSize.height - 12, width: pageSize.width, height: 12))

        var y: CGFloat = 150
        if let logo = data.church.logoPNG, let image = UIImage(data: logo) {
            let side: CGFloat = 150
            image.draw(in: CGRect(x: (pageSize.width - side) / 2, y: 90, width: side, height: side))
            y = 270
        }
        if !data.church.name.isEmpty {
            text(data.church.name, at: y, font: .boldSystemFont(ofSize: 40), color: ink, center: true)
            y += 60
        }
        text(String(localized: "annual.yearInReview").uppercased(), at: y,
             font: .systemFont(ofSize: 30, weight: .medium), color: accent, center: true)
        y += 90
        text("\(data.year)", at: y, font: .boldSystemFont(ofSize: 130), color: accent, center: true)
    }

    private static func headlineSlide(_ ctx: UIGraphicsPDFRendererContext, _ data: AnnualReportData) {
        ctx.beginPage()
        slideTitle(String(localized: "annual.overview"))

        // Three big stat cards.
        let cardW = (pageSize.width - 2 * margin - 2 * 30) / 3
        let cardY: CGFloat = 180
        let cardH: CGFloat = 220
        statCard(x: margin, y: cardY, w: cardW, h: cardH,
                 title: String(localized: "report.totalIncomes"),
                 value: Money.format(data.incomeTotalCents), color: income)
        statCard(x: margin + cardW + 30, y: cardY, w: cardW, h: cardH,
                 title: String(localized: "report.totalExpenses"),
                 value: Money.format(data.expenseTotalCents), color: expense)
        let net = data.earningLossCents
        statCard(x: margin + 2 * (cardW + 30), y: cardY, w: cardW, h: cardH,
                 title: String(localized: "report.earningLoss"),
                 value: Money.format(net), color: net >= 0 ? income : expense)

        // Net asset line.
        let ny: CGFloat = 470
        text(String(format: String(localized: "annual.netAssetLine"),
                    Money.format(data.beginningNetAssetCents),
                    Money.format(data.endingNetAssetCents)),
             at: ny, font: .systemFont(ofSize: 30, weight: .medium), color: ink, center: true)

        text(String(format: String(localized: "annual.averageLine"),
                    Money.format(data.averageMonthlyIncomeCents),
                    Money.format(data.averageMonthlyExpenseCents)),
             at: ny + 60, font: .systemFont(ofSize: 24), color: .secondaryLabel, center: true)
    }

    private static func monthlyTrendSlide(_ ctx: UIGraphicsPDFRendererContext, _ data: AnnualReportData) {
        ctx.beginPage()
        slideTitle(String(localized: "annual.monthlyTrend"))
        legend()
        let chartRect = CGRect(x: margin + 70, y: 170,
                               width: pageSize.width - 2 * margin - 90, height: 470)
        drawMonthlyBars(ctx.cgContext, rect: chartRect, months: data.months)
    }

    private static func categorySlide(_ ctx: UIGraphicsPDFRendererContext, _ data: AnnualReportData) {
        ctx.beginPage()
        slideTitle(String(localized: "annual.expenseBreakdown"))

        let top = Array(data.expenseCategories.prefix(8))
        let maxVal = max(top.map(\.cents).max() ?? 1, 1)
        let rowH: CGFloat = 56
        let labelW: CGFloat = 300
        let barMaxW = pageSize.width - margin - labelW - 220
        var y: CGFloat = 180
        for cat in top {
            text(cat.name, at: y + 8, x: margin, font: .systemFont(ofSize: 24), color: ink, center: false)
            let w = barMaxW * CGFloat(cat.cents) / CGFloat(maxVal)
            bar(CGRect(x: margin + labelW, y: y, width: max(w, 2), height: 36), color: accent)
            text(Money.format(cat.cents), at: y + 6, x: margin + labelW + w + 12,
                 font: .boldSystemFont(ofSize: 22), color: ink, center: false)
            y += rowH
            if y > pageSize.height - margin { break }
        }
        if top.isEmpty {
            text(String(localized: "annual.noExpenses"), at: 340,
                 font: .systemFont(ofSize: 26), color: .secondaryLabel, center: true)
        }
    }

    private static func highlightsSlide(_ ctx: UIGraphicsPDFRendererContext, _ data: AnnualReportData) {
        ctx.beginPage()
        slideTitle(String(localized: "annual.highlights"))
        var y: CGFloat = 180
        let f = UIFont.systemFont(ofSize: 28)
        func line(_ s: String) { text(s, at: y, x: margin, font: f, color: ink, center: false); y += 62 }

        line(String(format: String(localized: "annual.givingLine"),
                    "\(data.donorCount)", Money.format(data.givingTotalCents)))
        line(String(format: String(localized: "annual.regularSpecialLine"),
                    Money.format(data.regularExpenseCents), Money.format(data.specialExpenseCents)))
        if let peak = data.peakIncomeMonth, peak.incomeCents > 0 {
            line(String(format: String(localized: "annual.peakIncomeLine"),
                        monthName(peak.month), Money.format(peak.incomeCents)))
        }
        if let peak = data.peakExpenseMonth, peak.expenseCents > 0 {
            line(String(format: String(localized: "annual.peakExpenseLine"),
                        monthName(peak.month), Money.format(peak.expenseCents)))
        }
    }

    // MARK: - Chart drawing

    private static func drawMonthlyBars(_ cg: CGContext, rect: CGRect, months: [AnnualReportData.MonthPoint]) {
        let maxVal = max(months.map { max($0.incomeCents, $0.expenseCents) }.max() ?? 1, 1)
        let baseY = rect.maxY - 34
        let topY = rect.minY
        let chartH = baseY - topY
        let groupW = rect.width / 12

        // Horizontal gridlines + y labels (4 steps).
        UIColor.systemGray4.setStroke()
        for step in 0...4 {
            let value = maxVal * step / 4
            let gy = baseY - chartH * CGFloat(step) / 4
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX, y: gy))
            path.addLine(to: CGPoint(x: rect.maxX, y: gy))
            path.lineWidth = 0.5
            path.stroke()
            drawRight(moneyShort(value), rightX: rect.minX - 10, centerY: gy,
                      font: .systemFont(ofSize: 15), color: .secondaryLabel)
        }

        let barW = groupW * 0.30
        for i in 0..<12 {
            let gx = rect.minX + CGFloat(i) * groupW + groupW / 2
            let incH = chartH * CGFloat(months[i].incomeCents) / CGFloat(maxVal)
            let expH = chartH * CGFloat(months[i].expenseCents) / CGFloat(maxVal)
            bar(CGRect(x: gx - barW - 2, y: baseY - incH, width: barW, height: incH), color: income)
            bar(CGRect(x: gx + 2, y: baseY - expH, width: barW, height: expH), color: expense)
            drawCentered(monthAbbrev(i + 1), centerX: gx, y: baseY + 8,
                         font: .systemFont(ofSize: 16, weight: .medium), color: .label)
        }

        UIColor.label.setStroke()
        let axis = UIBezierPath()
        axis.move(to: CGPoint(x: rect.minX, y: baseY))
        axis.addLine(to: CGPoint(x: rect.maxX, y: baseY))
        axis.lineWidth = 1.5
        axis.stroke()
    }

    private static func legend() {
        let y: CGFloat = 130
        var x: CGFloat = margin + 70
        bar(CGRect(x: x, y: y, width: 26, height: 20), color: income)
        text(String(localized: "report.totalIncomes"), at: y - 2, x: x + 34,
             font: .systemFont(ofSize: 18), color: .label, center: false)
        x += 220
        bar(CGRect(x: x, y: y, width: 26, height: 20), color: expense)
        text(String(localized: "report.totalExpenses"), at: y - 2, x: x + 34,
             font: .systemFont(ofSize: 18), color: .label, center: false)
    }

    // MARK: - Primitives

    private static func slideTitle(_ title: String) {
        accent.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageSize.width, height: 8)).fill()
        text(title, at: 44, x: margin, font: .boldSystemFont(ofSize: 40), color: ink, center: false)
    }

    private static func statCard(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                 title: String, value: String, color: UIColor) {
        let card = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 16)
        color.withAlphaComponent(0.12).setFill()
        card.fill()
        text(title, at: y + 28, x: x, width: w, font: .systemFont(ofSize: 24, weight: .medium),
             color: .secondaryLabel, center: true)
        drawCentered(value, centerX: x + w / 2, y: y + h / 2 - 6,
                     font: .boldSystemFont(ofSize: 50), color: color)
    }

    private static func bar(_ rect: CGRect, color: UIColor) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 3).fill()
    }

    private static func text(_ string: String, at y: CGFloat, x: CGFloat = 0,
                             width: CGFloat? = nil, font: UIFont, color: UIColor, center: Bool) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = center ? .center : .left
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color,
                                                     .paragraphStyle: paragraph]
        let w = width ?? (pageSize.width - (center ? 0 : x) - (center ? 0 : margin))
        let rx = center && width == nil ? 0 : x
        (string as NSString).draw(in: CGRect(x: rx, y: y, width: w, height: font.lineHeight + 6),
                                  withAttributes: attrs)
    }

    private static func drawCentered(_ string: String, centerX: CGFloat, y: CGFloat,
                                     font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (string as NSString).size(withAttributes: attrs)
        (string as NSString).draw(at: CGPoint(x: centerX - size.width / 2, y: y), withAttributes: attrs)
    }

    private static func drawRight(_ string: String, rightX: CGFloat, centerY: CGFloat,
                                  font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (string as NSString).size(withAttributes: attrs)
        (string as NSString).draw(at: CGPoint(x: rightX - size.width, y: centerY - size.height / 2),
                                  withAttributes: attrs)
    }

    // MARK: - Helpers

    private static func moneyShort(_ cents: Int) -> String {
        let dollars = Double(cents) / 100
        if abs(dollars) >= 1000 {
            return String(format: "$%.1fK", dollars / 1000)
        }
        return "$\(Int(dollars))"
    }

    private static func monthAbbrev(_ month: Int) -> String {
        DateFormatter().shortMonthSymbols[(month - 1) % 12]
    }
    private static func monthName(_ month: Int) -> String {
        DateFormatter().monthSymbols[(month - 1) % 12]
    }
}
