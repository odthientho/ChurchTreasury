import Foundation

extension String {
    /// A folded form for tolerant name matching: diacritics and case removed,
    /// so a Vietnamese name written with accents matches the same name typed in
    /// plain ASCII — e.g. "Nguyễn" and "Nguyen", "Trần" and "Tran". Uses a
    /// fixed POSIX locale for stable, language-independent folding.
    var diacriticInsensitive: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Case- and accent-insensitive equality (for name matching).
    func matchesLoosely(_ other: String) -> Bool {
        diacriticInsensitive == other.diacriticInsensitive
    }

    /// Case- and accent-insensitive containment (for search fields).
    func containsLoosely(_ needle: String) -> Bool {
        diacriticInsensitive.contains(needle.diacriticInsensitive)
    }
}
