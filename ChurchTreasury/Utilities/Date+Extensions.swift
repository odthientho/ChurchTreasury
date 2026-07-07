import Foundation

extension Date {
    /// First moment of this date's month.
    var startOfMonth: Date {
        let comps = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: comps) ?? self
    }

    /// First moment of the next month (exclusive upper bound for queries).
    var startOfNextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? self
    }

    /// The most recent Sunday on or before this date — the default service date.
    var previousSunday: Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: self)
        let daysBack = (weekday - 1) % 7
        let day = cal.date(byAdding: .day, value: -daysBack, to: self) ?? self
        return cal.startOfDay(for: day)
    }

    var monthYearLabel: String {
        formatted(.dateTime.month(.wide).year())
    }
}
