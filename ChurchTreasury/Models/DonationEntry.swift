import Foundation
import SwiftData

enum DonationMethod: String, Codable, CaseIterable, Identifiable {
    case check
    case envelopeCash

    var id: Self { self }

    var localizedName: String {
        switch self {
        case .check: String(localized: "donation.method.check")
        case .envelopeCash: String(localized: "donation.method.envelopeCash")
        }
    }
}

@Model
final class DonationEntry {
    var amountCents: Int = 0
    var methodRaw: String = DonationMethod.check.rawValue
    var checkNumber: String?
    var envelopeNumber: String?
    var createdAt: Date = Date()
    /// Filename of the check/envelope photo within `AttachmentStore`'s
    /// "Offering Photos" folder — the image itself lives on disk, not in the
    /// database, kept for the treasurer's audit trail.
    var checkImageFilename: String?

    var donor: Donor?
    var batch: OfferingBatch?

    // Relationships (donor, batch) must be set after the entry is inserted
    // into a context — assigning them in the initializer crashes SwiftData.
    init(amountCents: Int = 0, method: DonationMethod = .check,
         checkNumber: String? = nil, envelopeNumber: String? = nil) {
        self.amountCents = amountCents
        self.methodRaw = method.rawValue
        self.checkNumber = checkNumber
        self.envelopeNumber = envelopeNumber
        self.createdAt = Date()
    }

    var method: DonationMethod {
        get { DonationMethod(rawValue: methodRaw) ?? .check }
        set { methodRaw = newValue.rawValue }
    }
}
