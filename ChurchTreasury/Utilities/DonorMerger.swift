import SwiftData

/// Merges several donor records into one — for when the same person was
/// written slightly differently on paper (e.g. "Hai Nguyen" vs "Nguyen Hai")
/// and ended up as separate donors. All donations from the duplicates are
/// reassigned to the surviving donor so giving totals and year-end statements
/// combine correctly, then the duplicate records are deleted.
enum DonorMerger {

    /// Reassigns every donation from `duplicates` to `keeper`, deletes the
    /// duplicates, sets the kept donor's real name to `canonicalName`, and
    /// records every other spelling (the keeper's old name, the duplicates'
    /// names, and any of their existing aliases) as `aliases`. `keeper`'s
    /// blank contact fields are backfilled from a duplicate that has them.
    @MainActor
    static func merge(into keeper: Donor, duplicates: [Donor],
                      canonicalName: String, context: ModelContext) {
        // Gather every spelling before we overwrite the keeper's name.
        let everyName = ([keeper] + duplicates).flatMap { [$0.name] + $0.aliases }

        for donor in duplicates where donor !== keeper {
            // Snapshot first — appending to keeper.donations mutates the
            // source array (SwiftData moves the inverse), so we must not
            // iterate donor.donations directly while changing it.
            let entries = donor.donations ?? []
            for entry in entries {
                if keeper.donations == nil { keeper.donations = [] }
                // Forward-array append is the app-wide pattern that reliably
                // updates the inverse (entry.donor) and triggers Observation.
                keeper.donations?.append(entry)
            }

            // Fill in any contact detail the keeper is missing.
            if (keeper.envelopeNumber ?? "").isEmpty { keeper.envelopeNumber = donor.envelopeNumber }
            if (keeper.address ?? "").isEmpty { keeper.address = donor.address }
            if (keeper.phone ?? "").isEmpty { keeper.phone = donor.phone }
            if let note = donor.note, !note.isEmpty {
                keeper.note = (keeper.note ?? "").isEmpty ? note : (keeper.note! + "\n" + note)
            }

            context.delete(donor)
        }

        let trimmedCanonical = canonicalName.trimmingCharacters(in: .whitespaces)
        if !trimmedCanonical.isEmpty { keeper.name = trimmedCanonical }

        // Every distinct spelling that isn't the chosen real name becomes an
        // alias (case-insensitive de-dupe, order preserved).
        var seen = Set<String>([keeper.name.lowercased()])
        var aliases: [String] = []
        for raw in everyName {
            let n = raw.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { continue }
            let key = n.lowercased()
            if seen.insert(key).inserted { aliases.append(n) }
        }
        keeper.aliases = aliases

        try? context.save()
    }
}
