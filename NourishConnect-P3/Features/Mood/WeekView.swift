import SwiftUI
import SwiftData

/// Seven days of mood and meals side by side, so food and mood can be seen together.
/// Everything comes from what is saved on the phone.
struct WeekView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]

    @Query private var alerts: [AlertEvent]

    private var days: [DaySummary] {
        WeekSummary.build(
            meals: meals.map { (date: $0.date, rating: $0.rating) },
            moods: moods.map { (date: $0.date, level: $0.level) },
            now: .now
        )
    }

    private func alertCount(in week: [DaySummary]) -> Int {
        guard let oldest = week.last?.day else { return 0 }
        return alerts.filter { $0.date >= oldest }.count
    }

    var body: some View {
        let week = days
        let spoken = WeekSummary.spoken(week)

        ScrollView {
            VStack(spacing: 14) {
                Text(spoken)
                    .font(theme.font(22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                ForEach(week) { day in
                    DayRow(day: day)
                }

                ReadAloudButton(text: spoken)

                ShareLink(item: WeekShareText.build(week, alertCount: alertCount(in: week))) {
                    Label(Str.shareButton, systemImage: "square.and.arrow.up")
                        .font(theme.font(20, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text(Str.shareNote)
                    .font(theme.font(16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .navigationTitle(Str.weekTitle)
        .navigationBarTitleDisplayMode(.inline)
        .speaksOnAppear(spoken)
    }
}

private struct DayRow: View {
    @Environment(\.theme) private var theme

    let day: DaySummary

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_HK")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private var dayName: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day.day) { return Str.today }
        if calendar.isDateInYesterday(day.day) { return Str.yesterday }
        return Self.weekdayFormatter.string(from: day.day)
    }

    private var moodSymbol: String {
        switch day.moodLevel {
        case 0: return "sun.max.fill"
        case 1: return "cloud.fill"
        case 2: return "cloud.rain.fill"
        default: return "minus.circle"
        }
    }

    private var moodText: String {
        day.moodLevel.map { Str.moodWord($0) } ?? Str.noMood
    }

    private var mealText: String {
        if day.mealCount == 0 { return Str.noMeals }
        var text = Str.mealsCount(day.mealCount)
        if day.higherCount > 0 { text += "，\(Str.highFoodNote)" }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dayName)
                .font(theme.font(22, weight: .bold))
            HStack(spacing: 12) {
                Image(systemName: moodSymbol)
                    .font(theme.font(26))
                    .frame(minWidth: 36)
                Text(moodText)
                    .font(theme.font(20))
            }
            HStack(spacing: 12) {
                Image(systemName: day.higherCount > 0 ? "exclamationmark.triangle.fill" : "fork.knife")
                    .font(theme.font(26))
                    .foregroundStyle(day.higherCount > 0 ? Color.orange : Color.primary)
                    .frame(minWidth: 36)
                Text(mealText)
                    .font(theme.font(20))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
