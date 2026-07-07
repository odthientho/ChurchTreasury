import Foundation

/// What should happen when the treasurer picks a date on one of the
/// quick-entry screens (Checks/Envelopes/Loose Cash).
enum BatchDateMatch {
    /// An open collection already exists for that day — add to it.
    case useExisting(OfferingBatch)
    /// No collection exists for that day yet — one will be created on the
    /// first actual entry (not eagerly, so scrubbing the date picker
    /// doesn't leave behind empty orphan batches).
    case createNew
    /// Every collection recorded for that day is already deposited (or
    /// reconciled) — the caller must ask the treasurer whether to add to
    /// that collection anyway or start a separate one for the same date.
    case needsDepositedChoice(OfferingBatch)
}

enum BatchDateResolver {
    static func resolve(date: Date, among batches: [OfferingBatch]) -> BatchDateMatch {
        let matches = batches.filter { Calendar.current.isDate($0.serviceDate, inSameDayAs: date) }
        if let open = matches.first(where: { $0.status == .open }) {
            return .useExisting(open)
        }
        if let locked = matches.first(where: { $0.status != .open }) {
            return .needsDepositedChoice(locked)
        }
        return .createNew
    }
}

/// UI-facing resolution state shared by the quick-entry screens: tracks
/// whether a target batch is ready to receive entries, still needs to be
/// lazily created, or is blocked pending the treasurer's deposited-day choice.
enum BatchResolutionState {
    case ready(OfferingBatch)
    case willCreate
    case needsChoice(OfferingBatch)

    var isAwaitingChoice: Bool {
        if case .needsChoice = self { return true }
        return false
    }

    var readyBatch: OfferingBatch? {
        if case .ready(let batch) = self { return batch }
        return nil
    }
}
