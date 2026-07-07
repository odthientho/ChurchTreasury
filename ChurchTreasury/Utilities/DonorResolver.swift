import SwiftData

/// Matches a typed name against existing donors, or creates a new donor —
/// shared by the manual quick-add row and the check-scan review screen so
/// first-time donors can be added without leaving either flow.
enum DonorResolver {
    @MainActor
    static func resolveOrCreate(name: String, existing: [Donor], context: ModelContext) -> Donor? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Match the name or any recorded alias, ignoring case AND accents, so a
        // Vietnamese name typed without diacritics (e.g. "Nguyen") resolves to
        // the same donor as "Nguyễn" instead of creating a duplicate.
        if let match = existing.first(where: {
            $0.name.matchesLoosely(trimmed)
                || $0.aliases.contains { $0.matchesLoosely(trimmed) }
        }) {
            return match
        }
        let donor = Donor(name: trimmed)
        context.insert(donor)
        return donor
    }
}
