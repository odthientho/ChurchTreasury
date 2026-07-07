import UIKit

/// Minimal top-down PDF layout on US Letter with automatic page breaks.
/// Shared by the monthly report and giving statements.
@MainActor
final class PDFComposer {
    static let pageSize = CGSize(width: 612, height: 792)   // US Letter @72dpi
    static let margin: CGFloat = 54

    struct Column {
        var widthFraction: CGFloat
        var alignment: NSTextAlignment = .left
    }

    private var currentY: CGFloat = 0
    private var context: UIGraphicsPDFRendererContext!

    private var contentWidth: CGFloat { Self.pageSize.width - 2 * Self.margin }
    private var bottomLimit: CGFloat { Self.pageSize.height - Self.margin }

    func render(_ body: (PDFComposer) -> Void) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: Self.pageSize)
        )
        return renderer.pdfData { ctx in
            self.context = ctx
            self.beginPage()
            body(self)
        }
    }

    private func beginPage() {
        context.beginPage()
        currentY = Self.margin
    }

    private func ensureSpace(_ height: CGFloat) {
        if currentY + height > bottomLimit {
            beginPage()
        }
    }

    func spacer(_ height: CGFloat) {
        currentY += height
    }

    func pageBreak() {
        beginPage()
    }

    func line() {
        ensureSpace(8)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: Self.margin, y: currentY + 4))
        path.addLine(to: CGPoint(x: Self.pageSize.width - Self.margin, y: currentY + 4))
        UIColor.gray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        currentY += 8
    }

    /// Draws an image (e.g. the church logo) centered, fit within the content
    /// width and `maxHeight`, and advances the cursor below it.
    func image(_ data: Data, maxHeight: CGFloat) {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return }
        let fit = min(maxHeight / image.size.height, contentWidth / image.size.width, 1)
        let w = image.size.width * fit
        let h = image.size.height * fit
        ensureSpace(h + 6)
        image.draw(in: CGRect(x: Self.margin + (contentWidth - w) / 2, y: currentY,
                              width: w, height: h))
        currentY += h + 6
    }

    func text(_ string: String, font: UIFont, color: UIColor = .black,
              alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let bounds = attributed.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], context: nil
        )
        ensureSpace(bounds.height + 4)
        attributed.draw(in: CGRect(x: Self.margin, y: currentY,
                                   width: contentWidth, height: bounds.height))
        currentY += bounds.height + 4
    }

    func tableRow(_ cells: [String], columns: [Column], font: UIFont,
                  color: UIColor = .black, fillColor: UIColor? = nil) {
        let rowHeight = font.lineHeight + 6
        ensureSpace(rowHeight)

        if let fillColor {
            fillColor.setFill()
            UIBezierPath(rect: CGRect(x: Self.margin, y: currentY,
                                      width: contentWidth, height: rowHeight)).fill()
        }

        var x = Self.margin
        for (index, cell) in cells.enumerated() where index < columns.count {
            let column = columns[index]
            let width = contentWidth * column.widthFraction
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = column.alignment
            paragraph.lineBreakMode = .byTruncatingTail
            let attributed = NSAttributedString(string: cell, attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
            ])
            attributed.draw(in: CGRect(x: x + 2, y: currentY + 3,
                                       width: width - 4, height: font.lineHeight + 2))
            x += width
        }
        currentY += rowHeight
    }
}
