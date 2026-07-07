import UIKit

/// Stores the one church logo the treasurer imports in Settings. Kept as a
/// single PNG (preserving any transparency) under `Documents/Church Logo/` so
/// it travels with the rest of the data in the Files-app handoff, alongside
/// the SwiftData store and the photo folders (see `AttachmentStore`). The logo
/// is drawn on the printed weekly report and the donor giving statements.
enum ChurchLogoStore {
    static let folderName = "Church Logo"
    private static let fileName = "logo.png"

    private static var folderURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private static var fileURL: URL { folderURL.appendingPathComponent(fileName) }

    /// Downscales to a sensible maximum and writes as PNG (keeps transparency).
    @discardableResult
    static func save(_ image: UIImage) -> Bool {
        let maxDimension: CGFloat = 1024
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.pngData() else { return false }
        return (try? data.write(to: fileURL, options: .atomic)) != nil
    }

    /// Raw PNG bytes for PDF rendering (Sendable, unlike `UIImage`).
    static func pngData() -> Data? { try? Data(contentsOf: fileURL) }

    static func load() -> UIImage? { pngData().flatMap(UIImage.init(data:)) }

    static func delete() { try? FileManager.default.removeItem(at: fileURL) }
}
