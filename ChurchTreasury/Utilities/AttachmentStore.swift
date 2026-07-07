import Foundation
import UIKit

/// Persists user-attached photos — offering check/envelope images, expense
/// receipts, and images of checks written to pay expenses — as files on disk
/// instead of database blobs. Every folder lives under `Documents/` so the
/// whole Documents tree (the SwiftData store plus all these photos) can be
/// handed to the next treasurer in one piece via the Files app.
enum AttachmentStore {
    /// Each kind of attachment gets its own human-readable subfolder, so the
    /// Files-app view is self-explanatory when browsing the handoff data.
    enum Folder: String {
        case offeringPhotos = "Offering Photos"
        case expenseReceipts = "Expense Receipts"
        case expenseChecks = "Expense Check Images"
        case depositReceipts = "Deposit Receipts"
    }

    private static func folderURL(_ folder: Folder) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent(folder.rawValue, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Writes image data to a new file in the given folder and returns its
    /// filename. Only the filename (not the full path) is stored on the model,
    /// since the containing directory can move between app launches/devices.
    static func save(_ data: Data, in folder: Folder) -> String? {
        let filename = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: folderURL(folder).appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String, from folder: Folder) -> UIImage? {
        guard let data = try? Data(contentsOf: folderURL(folder).appendingPathComponent(filename)) else {
            return nil
        }
        return UIImage(data: data)
    }

    static func delete(_ filename: String, from folder: Folder) {
        try? FileManager.default.removeItem(at: folderURL(folder).appendingPathComponent(filename))
    }

    /// Downscales and compresses a photo before it's written to disk — full
    /// resolution camera photos are unnecessarily large for a record photo.
    static func compressed(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1600
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale,
                                height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.6)
    }
}
