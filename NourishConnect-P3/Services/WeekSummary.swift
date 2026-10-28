import Foundation

/// One day of meals and mood, for the weekly view and the chat context.
struct DaySummary: Identifiable, Equatable {
    let day: Date
    /// Worst mood that day: 0 okay, 1 a bit lonely, 2 not well. Nil if no mood check.
    let moodLevel: Int?
    let mealCount: Int
    /// Meals whose overall rating was "higher".
    let higherCount: Int
    /// Worst meal rating that day, if any meal could be rated.
    let worstMeal: Level?

    var id: Date { day }
}

enum WeekSummary {
    /// Newest day first. `days` calendar days ending today.
    static func build(meals: [(date: Date, rating: String)],
                      moods: [(date: Date, level: Int)],
                      now: Date,
                      calendar: Calendar = .current,
                      days: Int = 7) -> [DaySummary] {
        let today = calendar.startOfDay(for: now)
        var result: [DaySummary] = []

        for offset in 0..<days {
            guard
                let start = calendar.date(byAdding: .day, value: -offset, to: today),
                let end = calendar.date(byAdding: .day, value: 1, to: start)
            else { continue }

            let dayMoods = moods.filter { $0.date >= start && $0.date < end }
            let dayMeals = meals.filter { $0.date >= start && $0.date < end }
            let levels: [Level] = dayMeals.compactMap { Level(storageKey: $0.rating) }

            result.append(DaySummary(
                day: start,
                moodLevel: dayMoods.map { $0.level }.max(),
                mealCount: dayMeals.count,
                higherCount: levels.filter { $0 == .higher }.count,
                worstMeal: levels.max()
            ))
        }
        return result
    }
}

extension WeekSummary {
    /// One sentence for the weekly view to read aloud.
    static func spoken(_ days: [DaySummary]) -> String {
        let moodDays = days.filter { $0.moodLevel != nil }.count
        let meals = days.map { $0.mealCount }.reduce(0, +)
        let higher = days.map { $0.higherCount }.reduce(0, +)
        if moodDays == 0 && meals == 0 {
            return Str.weekEmpty
        }
        return Str.weekSpoken(moodDays: moodDays, meals: meals, higher: higher)
    }
}

/// Plain text of the week that the user can choose to send to family or a worker.
/// Counts and mood words only: no product names, no times, no chat text.
/// Nothing is sent by the app; the user picks the recipient in the share sheet.
enum WeekShareText {
    static func build(_ days: [DaySummary], alertCount: Int, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_HK")
        formatter.calendar = calendar
        formatter.dateFormat = "M月d日 EEEE"

        var lines = [Str.shareHeader]
        for day in days.reversed() {
            var parts = [day.moodLevel.map { Str.moodWord($0) } ?? Str.noMood]
            parts.append(day.mealCount == 0 ? Str.noMeals : Str.mealsCount(day.mealCount))
            if day.higherCount > 0 { parts.append(Str.highFoodNote) }
            lines.append("\(formatter.string(from: day.day))：" + parts.joined(separator: "，"))
        }
        if alertCount > 0 {
            lines.append(Str.shareAlerts(alertCount))
        }
        lines.append(Str.shareFooter)
        return lines.joined(separator: "\n")
    }
}

/// Short facts about today, sent with a chat message so the reply can refer to them.
/// Counts and levels only: no product names, no names of people, no times.
enum ChatContext {
    static func lines(for today: DaySummary?) -> [String] {
        guard let today else { return [] }
        var lines: [String] = []
        if let mood = today.moodLevel {
            lines.append("今日心情記錄：\(Str.moodWord(mood))")
        }
        if today.mealCount > 0 {
            var line = "今日食物記錄：\(today.mealCount)樣"
            if today.higherCount > 0 {
                line += "，其中\(today.higherCount)樣糖或鈉偏高"
            }
            lines.append(line)
        }
        return lines
    }
}

/// Fixed tips used when the chat is offline or its reply is blocked.
/// A nurse or dietitian must approve this wording.
enum TipFallback {
    static func tip(for today: DaySummary?, now: Date, calendar: Calendar = .current) -> String {
        if let today {
            if today.higherCount > 0 { return Str.tipHighFood }
            if let mood = today.moodLevel, mood >= 1 { return Str.tipLonely }
        }
        let general = [Str.tipGeneral1, Str.tipGeneral2, Str.tipGeneral3]
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        return general[day % general.count]
    }
}
