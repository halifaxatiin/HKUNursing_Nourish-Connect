import Foundation
import SwiftData

/// Fictional week of meals and moods for demos and screenshots.
/// Demo rows are marked ("demo" in MealEntry.note and MoodEntry.source) so clearing
/// removes only them. Never contains real people's data.
enum DemoData {
    static let marker = "demo"

    /// Oldest day first. Each entry: days ago, mood level (nil = none), meals as (name, rating).
    static let plan: [(daysAgo: Int, mood: Int?, meals: [(String, Level)])] = [
        (6, 0, [("燕麥", .lower), ("蒸魚飯", .middle)]),
        (5, 0, [("無糖豆漿", .lower)]),
        (4, 1, [("甜麵包", .higher), ("白粥", .middle)]),
        (3, 1, [("罐頭湯", .higher)]),
        (2, nil, [("清蒸菜", .lower)]),
        (1, 2, [("即食麵", .higher)]),
        (0, 1, [("麥皮", .lower)])
    ]

    static func load(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        clear(from: context)
        let today = calendar.startOfDay(for: now)
        for item in plan {
            guard let day = calendar.date(byAdding: .day, value: -item.daysAgo, to: today) else { continue }
            if let mood = item.mood,
               let time = calendar.date(byAdding: .hour, value: 9, to: day) {
                context.insert(MoodEntry(date: time, level: mood, source: marker))
            }
            for (index, meal) in item.meals.enumerated() {
                guard let time = calendar.date(byAdding: .hour, value: 12 + index * 5, to: day) else { continue }
                context.insert(MealEntry(date: time, source: "label", name: meal.0,
                                         rating: meal.1.storageKey, note: marker))
            }
        }
    }

    static func clear(from context: ModelContext) {
        let marker = Self.marker
        let meals = (try? context.fetch(FetchDescriptor<MealEntry>(predicate: #Predicate { $0.note == marker }))) ?? []
        let moods = (try? context.fetch(FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.source == marker }))) ?? []
        meals.forEach(context.delete)
        moods.forEach(context.delete)
    }
}
