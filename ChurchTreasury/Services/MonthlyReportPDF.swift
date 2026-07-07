import UIKit

/// Renders the monthly treasurer report for the deacon board.
@MainActor
enum MonthlyReportPDF {
    static func render(_ data: MonthlyReportData) -> Data {
        let composer = PDFComposer()
        let title = UIFont.boldSystemFont(ofSize: 18)
        let heading = UIFont.boldSystemFont(ofSize: 13)
        let body = UIFont.systemFont(ofSize: 10)
        let bodyBold = UIFont.boldSystemFont(ofSize: 10)
        let small = UIFont.systemFont(ofSize: 9)
        // Monospaced digits so the summary amounts line up in a clean column.
        let bodyMono = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let bodyBoldMono = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        let highlight = UIColor(white: 0.93, alpha: 1)

        let summaryColumns: [PDFComposer.Column] = [
            .init(widthFraction: 0.6),
            .init(widthFraction: 0.4, alignment: .right),
        ]

        return composer.render { pdf in
            // Header
            if let logo = data.church.logoPNG {
                pdf.image(logo, maxHeight: 64)
            }
            if !data.church.name.isEmpty {
                pdf.text(data.church.name, font: heading, alignment: .center)
            }
            if !data.church.address.isEmpty {
                pdf.text(data.church.address, font: small, color: .darkGray, alignment: .center)
            }
            pdf.spacer(4)
            pdf.text(String(format: String(localized: "report.operationFundTitle"),
                            data.month.monthYearLabel.uppercased()),
                     font: title, alignment: .center)
            pdf.spacer(8)

            // Net-asset summary: Beginning → Income → Expense → Earning/Loss → Ending.
            // Beginning and Ending are both highlighted (the anchors to check).
            pdf.tableRow([String(localized: "report.beginningNetAsset"),
                          Money.format(data.beginningNetAssetCents)],
                         columns: summaryColumns, font: bodyBoldMono,
                         fillColor: highlight)
            pdf.tableRow([String(localized: "report.totalIncomes"),
                          Money.format(data.incomeTotalCents)],
                         columns: summaryColumns, font: bodyMono)
            pdf.tableRow([String(localized: "report.totalExpenses"),
                          Money.format(data.expenseTotalCents)],
                         columns: summaryColumns, font: bodyMono)
            pdf.tableRow([String(localized: "report.earningLoss"),
                          Money.format(data.earningLossCents)],
                         columns: summaryColumns, font: bodyBoldMono)
            pdf.tableRow([String(localized: "report.endingNetAsset"),
                          Money.format(data.endingNetAssetCents)],
                         columns: summaryColumns, font: bodyBoldMono,
                         fillColor: highlight)
            pdf.spacer(12)

            // Weekly deposit table
            pdf.text(String(localized: "report.weeklyDeposits"), font: heading)
            pdf.line()
            let weekColumns: [PDFComposer.Column] = [
                .init(widthFraction: 0.30),
                .init(widthFraction: 0.22, alignment: .right),
                .init(widthFraction: 0.24, alignment: .right),
                .init(widthFraction: 0.24, alignment: .right),
            ]
            pdf.tableRow([
                String(localized: "offering.serviceDate"),
                String(localized: "report.deposit"),
                String(localized: "report.cashExpense"),
                String(localized: "report.contribution"),
            ], columns: weekColumns, font: bodyBold, fillColor: UIColor(white: 0.93, alpha: 1))
            for row in data.incomeRows {
                pdf.tableRow([
                    row.serviceDate.formatted(.dateTime.month().day().year()),
                    Money.format(row.depositCents),
                    Money.format(row.cashExpenseCents),
                    Money.format(row.contributionCents),
                ], columns: weekColumns, font: body)
            }
            pdf.tableRow([
                String(localized: "report.monthlyDeposit"),
                Money.format(data.depositTotalCents),
                Money.format(data.cashExpenseTotalCents),
                Money.format(data.incomeTotalCents),
            ], columns: weekColumns, font: bodyBold, fillColor: UIColor(white: 0.96, alpha: 1))
            pdf.spacer(14)

            // Regular then Special expense sections
            expenseSection(pdf, title: String(localized: "report.regularExpenses"),
                           rows: data.regularExpenseRows,
                           total: data.regularExpenseTotalCents,
                           totalLabel: String(localized: "report.totalRegular"),
                           heading: heading, bodyBold: bodyBold, body: body)
            // Page 1 ends with the regular expenses; special expenses always
            // start fresh on page 2.
            pdf.pageBreak()
            expenseSection(pdf, title: String(localized: "report.specialExpenses"),
                           rows: data.specialExpenseRows,
                           total: data.specialExpenseTotalCents,
                           totalLabel: String(localized: "report.totalSpecial"),
                           heading: heading, bodyBold: bodyBold, body: body)

            // Signature
            pdf.spacer(24)
            if !data.church.treasurerName.isEmpty {
                pdf.text(String(localized: "report.preparedBy") + ": " + data.church.treasurerName,
                         font: body)
            }
            pdf.text(String(localized: "report.generatedOn") + ": "
                        + Date().formatted(.dateTime.month().day().year()),
                     font: small, color: .darkGray)
        }
    }

    private static func expenseSection(_ pdf: PDFComposer, title: String,
                                       rows: [MonthlyReportData.ExpenseRow],
                                       total: Int, totalLabel: String,
                                       heading: UIFont, bodyBold: UIFont, body: UIFont) {
        pdf.text(title, font: heading)
        pdf.line()
        let columns: [PDFComposer.Column] = [
            .init(widthFraction: 0.12),
            .init(widthFraction: 0.14),
            .init(widthFraction: 0.34),
            .init(widthFraction: 0.24),
            .init(widthFraction: 0.16, alignment: .right),
        ]
        pdf.tableRow([
            String(localized: "expense.date"),
            String(localized: "expense.method"),
            String(localized: "recurring.description"),
            String(localized: "report.paidTo"),
            String(localized: "field.amount"),
        ], columns: columns, font: bodyBold, fillColor: UIColor(white: 0.93, alpha: 1))
        for row in rows {
            pdf.tableRow([
                row.date.formatted(.dateTime.month().day()),
                row.typeName,
                row.detail,
                row.payee,
                Money.format(row.amountCents),
            ], columns: columns, font: body)
        }
        pdf.tableRow([totalLabel, "", "", "", Money.format(total)],
                     columns: columns, font: bodyBold, fillColor: UIColor(white: 0.96, alpha: 1))
    }
}
