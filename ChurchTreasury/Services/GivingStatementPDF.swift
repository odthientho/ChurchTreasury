import UIKit

/// Renders annual per-donor contribution statements (US tax letters).
@MainActor
enum GivingStatementPDF {
    /// Renders one statement into an existing composer session.
    private static func renderStatement(_ data: GivingStatementData, into pdf: PDFComposer) {
        let title = UIFont.boldSystemFont(ofSize: 16)
        let heading = UIFont.boldSystemFont(ofSize: 12)
        let body = UIFont.systemFont(ofSize: 10)
        let bodyBold = UIFont.boldSystemFont(ofSize: 10)
        let small = UIFont.systemFont(ofSize: 9)

        if let logo = data.church.logoPNG {
            pdf.image(logo, maxHeight: 64)
        }
        if !data.church.name.isEmpty {
            pdf.text(data.church.name, font: heading, alignment: .center)
        }
        if !data.church.address.isEmpty {
            pdf.text(data.church.address, font: small, color: .darkGray, alignment: .center)
        }
        pdf.spacer(8)
        pdf.text(String(localized: "giving.title \(String(data.year))"), font: title, alignment: .center)
        pdf.spacer(10)

        pdf.text(data.donorName, font: bodyBold)
        if let address = data.donorAddress, !address.isEmpty {
            pdf.text(address, font: body)
        }
        pdf.spacer(10)

        let columns: [PDFComposer.Column] = [
            .init(widthFraction: 0.3),
            .init(widthFraction: 0.3),
            .init(widthFraction: 0.2),
            .init(widthFraction: 0.2, alignment: .right),
        ]
        pdf.tableRow([
            String(localized: "expense.date"),
            String(localized: "offering.method"),
            String(localized: "field.checkNumber"),
            String(localized: "field.amount"),
        ], columns: columns, font: bodyBold, fillColor: UIColor(white: 0.93, alpha: 1))
        for row in data.rows {
            pdf.tableRow([
                row.date.formatted(.dateTime.month().day().year()),
                row.methodName,
                row.checkNumber.map { "#\($0)" } ?? "",
                Money.format(row.amountCents),
            ], columns: columns, font: body)
        }
        pdf.tableRow([
            String(localized: "giving.total \(String(data.year))"), "", "",
            Money.format(data.totalCents),
        ], columns: columns, font: bodyBold, fillColor: UIColor(white: 0.96, alpha: 1))

        pdf.spacer(14)
        pdf.text(String(localized: "giving.taxNote"), font: small, color: .darkGray)
        pdf.spacer(8)
        pdf.text(String(localized: "giving.thankYou"), font: body)

        pdf.spacer(24)
        if !data.church.treasurerName.isEmpty {
            pdf.text(data.church.treasurerName, font: body)
            pdf.text(String(localized: "report.treasurer"), font: small, color: .darkGray)
        }
    }

    /// One donor per document.
    static func render(_ data: GivingStatementData) -> Data {
        PDFComposer().render { pdf in
            renderStatement(data, into: pdf)
        }
    }

    /// All donors in one document, one starting on each page, for batch printing.
    static func renderAll(_ statements: [GivingStatementData]) -> Data {
        let composer = PDFComposer()
        return composer.render { pdf in
            for (index, statement) in statements.enumerated() {
                if index > 0 { pdf.pageBreak() }
                renderStatement(statement, into: pdf)
            }
        }
    }
}
