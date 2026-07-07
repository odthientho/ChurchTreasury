import UIKit

/// The full-year audit packet: every income and expense line for the year plus
/// all attached evidence photos (receipts, check images, deposit slips) embedded
/// in one printable PDF — a self-contained record for the church audit.
@MainActor
enum AnnualAuditPDF {
    static func render(_ data: AnnualReportData) -> Data {
        let composer = PDFComposer()
        let title = UIFont.boldSystemFont(ofSize: 18)
        let heading = UIFont.boldSystemFont(ofSize: 13)
        let body = UIFont.systemFont(ofSize: 9)
        let bodyBold = UIFont.boldSystemFont(ofSize: 9)
        let small = UIFont.systemFont(ofSize: 9)
        let fill = UIColor(white: 0.93, alpha: 1)
        let totalFill = UIColor(white: 0.96, alpha: 1)

        return composer.render { pdf in
            // Header
            if let logo = data.church.logoPNG { pdf.image(logo, maxHeight: 60) }
            if !data.church.name.isEmpty {
                pdf.text(data.church.name, font: heading, alignment: .center)
            }
            if !data.church.address.isEmpty {
                pdf.text(data.church.address, font: small, color: .darkGray, alignment: .center)
            }
            pdf.spacer(4)
            pdf.text(String(format: String(localized: "audit.title"), "\(data.year)"),
                     font: title, alignment: .center)
            pdf.text(String(localized: "audit.subtitle"), font: small, color: .darkGray, alignment: .center)
            pdf.spacer(10)

            // Summary
            let sum: [PDFComposer.Column] = [.init(widthFraction: 0.6),
                                             .init(widthFraction: 0.4, alignment: .right)]
            pdf.text(String(localized: "audit.summary"), font: heading)
            pdf.line()
            pdf.tableRow([String(localized: "report.totalIncomes"), Money.format(data.incomeTotalCents)],
                         columns: sum, font: body)
            pdf.tableRow([String(localized: "report.totalExpenses"), Money.format(data.expenseTotalCents)],
                         columns: sum, font: body)
            pdf.tableRow([String(localized: "report.earningLoss"), Money.format(data.earningLossCents)],
                         columns: sum, font: bodyBold)
            pdf.tableRow([String(localized: "report.beginningNetAsset"), Money.format(data.beginningNetAssetCents)],
                         columns: sum, font: body)
            pdf.tableRow([String(localized: "report.endingNetAsset"), Money.format(data.endingNetAssetCents)],
                         columns: sum, font: bodyBold, fillColor: totalFill)
            pdf.spacer(12)

            // Income ledger
            pdf.text(String(localized: "audit.incomeLedger"), font: heading)
            pdf.line()
            let inc: [PDFComposer.Column] = [
                .init(widthFraction: 0.22), .init(widthFraction: 0.16, alignment: .right),
                .init(widthFraction: 0.16, alignment: .right), .init(widthFraction: 0.16, alignment: .right),
                .init(widthFraction: 0.16, alignment: .right), .init(widthFraction: 0.14),
            ]
            pdf.tableRow([String(localized: "offering.serviceDate"), String(localized: "offering.checks"),
                          String(localized: "offering.cash"), String(localized: "offering.total"),
                          String(localized: "report.deposit"), String(localized: "batch.status")],
                         columns: inc, font: bodyBold, fillColor: fill)
            for row in data.incomeRows {
                pdf.tableRow([row.date.formatted(.dateTime.month().day().year()),
                              Money.format(row.checksCents), Money.format(row.cashCents),
                              Money.format(row.totalCents), Money.format(row.depositCents), row.status],
                             columns: inc, font: body)
            }
            pdf.tableRow([String(localized: "report.totalIncomes"), "", "",
                          Money.format(data.incomeTotalCents), "", ""],
                         columns: inc, font: bodyBold, fillColor: totalFill)
            pdf.spacer(12)

            // Expense ledger
            pdf.text(String(localized: "audit.expenseLedger"), font: heading)
            pdf.line()
            let exp: [PDFComposer.Column] = [
                .init(widthFraction: 0.12), .init(widthFraction: 0.12), .init(widthFraction: 0.30),
                .init(widthFraction: 0.24), .init(widthFraction: 0.08),
                .init(widthFraction: 0.14, alignment: .right),
            ]
            pdf.tableRow([String(localized: "expense.date"), String(localized: "expense.method"),
                          String(localized: "recurring.description"), String(localized: "report.paidTo"),
                          String(localized: "field.checkNumber"), String(localized: "field.amount")],
                         columns: exp, font: bodyBold, fillColor: fill)
            for row in data.expenseRows {
                pdf.tableRow([row.date.formatted(.dateTime.month().day()), row.typeName, row.detail,
                              row.payee, row.checkNumber.map { "#\($0)" } ?? "",
                              Money.format(row.amountCents)],
                             columns: exp, font: body)
            }
            pdf.tableRow([String(localized: "report.totalExpenses"), "", "", "", "",
                          Money.format(data.expenseTotalCents)],
                         columns: exp, font: bodyBold, fillColor: totalFill)
            pdf.spacer(12)

            // Expenses by category
            pdf.text(String(localized: "report.expensesByCategory"), font: heading)
            pdf.line()
            for cat in data.expenseCategories {
                pdf.tableRow([cat.name, Money.format(cat.cents)], columns: sum, font: body)
            }

            // Evidence — every attached photo, captioned
            pdf.pageBreak()
            pdf.text(String(localized: "audit.evidenceTitle"), font: title, alignment: .center)
            pdf.text(String(format: String(localized: "audit.evidenceCount"), "\(data.evidence.count)"),
                     font: small, color: .darkGray, alignment: .center)
            pdf.spacer(8)
            if data.evidence.isEmpty {
                pdf.text(String(localized: "audit.noEvidence"), font: body, color: .darkGray)
            }
            for item in data.evidence {
                guard let image = AttachmentStore.load(item.filename, from: item.folder),
                      let jpeg = image.jpegData(compressionQuality: 0.8) else { continue }
                pdf.text(item.caption, font: bodyBold)
                pdf.image(jpeg, maxHeight: 300)
                pdf.spacer(10)
            }

            // Sign-off
            pdf.spacer(20)
            if !data.church.treasurerName.isEmpty {
                pdf.text(String(localized: "report.preparedBy") + ": " + data.church.treasurerName, font: body)
            }
            pdf.text(String(localized: "report.generatedOn") + ": "
                     + Date().formatted(.dateTime.month().day().year()), font: small, color: .darkGray)
        }
    }
}
