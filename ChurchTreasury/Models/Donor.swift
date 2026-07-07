import Foundation
import SwiftData

@Model
final class Donor {
    /// The one real name used everywhere in the app (reports, statements,
    /// entry). The `aliases` are alternate spellings written on paper.
    var name: String = ""
    /// Other spellings of this same person, gathered when duplicate donor
    /// records are combined. Shown in the donor list and matched during import
    /// so a variant spelling resolves to this donor instead of creating a new
    /// duplicate — but never used as the display name anywhere else.
    var aliases: [String] = []
    /// The donor's legal/real name, used ONLY on the year-end giving statement
    /// (tax receipt). Everywhere else — lists, entry, the app — uses `name`,
    /// which is the treasurer's own shorthand/nickname. Blank ⇒ fall back to
    /// `name` on the statement.
    var realName: String?
    var envelopeNumber: String?
    var address: String?
    var phone: String?
    var note: String?
    var createdAt: Date = Date()

    @Relationship(inverse: \DonationEntry.donor)
    var donations: [DonationEntry]? = []

    /// The name to print on the tax-receipt giving statement: the real/legal
    /// name if one was entered, otherwise the treasurer's shorthand `name`.
    var legalName: String {
        if let realName, !realName.trimmingCharacters(in: .whitespaces).isEmpty {
            return realName
        }
        return name
    }

    init(name: String = "", envelopeNumber: String? = nil, address: String? = nil,
         phone: String? = nil, note: String? = nil) {
        self.name = name
        self.envelopeNumber = envelopeNumber
        self.address = address
        self.phone = phone
        self.note = note
        self.createdAt = Date()
    }
}
