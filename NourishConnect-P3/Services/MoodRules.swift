import Foundation

enum MoodAction: Equatable {
    /// Nothing special.
    case none
    /// Latest check was "not well": answer kindly and offer a call, breathing or chat.
    case offerSupport
    /// A pattern over recent days: open the call screen.
    case alert
}

/// Decides what the app does after a mood check. Levels: 0 okay, 1 a bit lonely, 2 not well.
///
/// Starting rules, to be reviewed by a nurse:
/// - "Not well" on 2 or more of the last 3 calendar days: alert.
/// - "A bit lonely" or "not well" on all of the last 3 calendar days: alert.
/// - Otherwise, if the latest check is "not well": offer support.
/// Days are counted, not taps, so two accidental taps in one minute do not raise an alert.
enum MoodRules {
    static let windowDays = 3

    static func action(entries: [(date: Date, level: Int)],
                       now: Date,
                       calendar: Calendar = .current) -> MoodAction {
        guard let latest = entries.max(by: { $0.date < $1.date }) else { return .none }

        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) else {
            return .none
        }

        // Worst level per calendar day inside the window.
        var worstByDay: [Date: Int] = [:]
        for entry in entries where entry.date >= windowStart {
            let day = calendar.startOfDay(for: entry.date)
            worstByDay[day] = max(worstByDay[day] ?? 0, entry.level)
        }

        let notWellDays = worstByDay.values.filter { $0 >= 2 }.count
        let lowDays = worstByDay.values.filter { $0 >= 1 }.count

        if notWellDays >= 2 || lowDays >= windowDays {
            return .alert
        }
        return latest.level >= 2 ? .offerSupport : .none
    }
}
