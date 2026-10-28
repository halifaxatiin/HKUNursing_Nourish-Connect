import XCTest
import SwiftData
@testable import NourishConnect

final class BreathingPlanTests: XCTestCase {
    func testTwoMinutesIsTwelveCycles() {
        let steps = BreathingPlan.gentle.steps(totalSeconds: 120)
        XCTAssertEqual(steps.count, 24)
        XCTAssertEqual(steps.first, BreathingStep(phase: .inhale, seconds: 4))
        XCTAssertEqual(steps[1], BreathingStep(phase: .exhale, seconds: 6))
        XCTAssertEqual(steps.map(\.seconds).reduce(0, +), 120)
    }

    func testAlwaysAtLeastOneCycle() {
        XCTAssertEqual(BreathingPlan.gentle.steps(totalSeconds: 3).count, 2)
    }

    func testExhaleIsLongerThanInhale() {
        XCTAssertGreaterThan(BreathingPlan.gentle.exhaleSeconds, BreathingPlan.gentle.inhaleSeconds)
    }
}

final class WeekSummaryTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        return c
    }()

    private func at(daysAgo: Int, hour: Int) -> Date {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    private var now: Date { at(daysAgo: 0, hour: 12) }

    func testSevenDaysNewestFirst() {
        let days = WeekSummary.build(meals: [], moods: [], now: now, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertGreaterThan(days[0].day, days[1].day)
        XCTAssertEqual(days[0].day, calendar.startOfDay(for: now))
    }

    func testGroupsMealsAndMoodsByDay() {
        let meals: [(date: Date, rating: String)] = [
            (at(daysAgo: 0, hour: 8), "higher"),
            (at(daysAgo: 0, hour: 13), "lower"),
            (at(daysAgo: 1, hour: 19), "unrated")
        ]
        let moods: [(date: Date, level: Int)] = [
            (at(daysAgo: 0, hour: 9), 1),
            (at(daysAgo: 0, hour: 15), 2),
            (at(daysAgo: 2, hour: 9), 0)
        ]
        let days = WeekSummary.build(meals: meals, moods: moods, now: now, calendar: calendar)

        XCTAssertEqual(days[0].mealCount, 2)
        XCTAssertEqual(days[0].higherCount, 1)
        XCTAssertEqual(days[0].worstMeal, .higher)
        XCTAssertEqual(days[0].moodLevel, 2)

        XCTAssertEqual(days[1].mealCount, 1)
        XCTAssertNil(days[1].worstMeal)
        XCTAssertNil(days[1].moodLevel)

        XCTAssertEqual(days[2].moodLevel, 0)
    }

    func testWeekSpokenSentence() {
        XCTAssertEqual(WeekSummary.spoken([]), Str.weekEmpty)
        let empty = DaySummary(day: now, moodLevel: nil, mealCount: 0, higherCount: 0, worstMeal: nil)
        XCTAssertEqual(WeekSummary.spoken([empty]), Str.weekEmpty)

        let busy = [
            DaySummary(day: now, moodLevel: 1, mealCount: 2, higherCount: 1, worstMeal: .higher),
            DaySummary(day: now, moodLevel: 0, mealCount: 1, higherCount: 0, worstMeal: .lower)
        ]
        let text = WeekSummary.spoken(busy)
        XCTAssertTrue(text.contains("2日心情"))
        XCTAssertTrue(text.contains("3樣食物"))
        XCTAssertTrue(text.contains("1樣糖或鈉偏高"))
    }

    func testChatContextHasCountsOnly() {
        let today = DaySummary(day: now, moodLevel: 1, mealCount: 3, higherCount: 1, worstMeal: .higher)
        let lines = ChatContext.lines(for: today)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains(Str.moodWord(1)))
        XCTAssertTrue(lines[1].contains("3"))
        XCTAssertTrue(lines[1].contains("1"))
        XCTAssertTrue(ChatContext.lines(for: nil).isEmpty)
    }

    func testTipFallbackFollowsTheDay() {
        let highFood = DaySummary(day: now, moodLevel: nil, mealCount: 1, higherCount: 1, worstMeal: .higher)
        XCTAssertEqual(TipFallback.tip(for: highFood, now: now, calendar: calendar), Str.tipHighFood)
        let lonely = DaySummary(day: now, moodLevel: 1, mealCount: 0, higherCount: 0, worstMeal: nil)
        XCTAssertEqual(TipFallback.tip(for: lonely, now: now, calendar: calendar), Str.tipLonely)
        let plain = TipFallback.tip(for: nil, now: now, calendar: calendar)
        XCTAssertFalse(plain.isEmpty)
    }
}

final class ChatClientTests: XCTestCase {
    func testBodyKeepsOnlyRecentTurnsAndShortText() throws {
        var history: [ChatTurn] = []
        for i in 0..<12 {
            history.append(ChatTurn(role: i % 2 == 0 ? .user : .assistant, text: "第\(i)句"))
        }
        history.append(ChatTurn(role: .user, text: String(repeating: "字", count: 900)))

        let data = try ChatClient.makeBody(history: history, context: Array(repeating: "x", count: 9), installID: "abc")
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try XCTUnwrap(object["messages"] as? [[String: String]])

        XCTAssertEqual(messages.count, ChatClient.maxTurns)
        XCTAssertEqual(messages.last?["role"], "user")
        XCTAssertEqual(messages.last?["content"]?.count, ChatClient.maxTurnLength)
        XCTAssertEqual((object["context"] as? [String])?.count, 5)
        XCTAssertEqual(object["installId"] as? String, "abc")
    }

    func testParseReplyOk() throws {
        let data = Data(#"{"reply":"你好"}"#.utf8)
        XCTAssertEqual(try ChatClient.parseReply(data: data, status: 200), "你好")
    }

    func testParseReplyErrors() {
        XCTAssertThrowsError(try ChatClient.parseReply(data: Data(), status: 429)) {
            XCTAssertEqual($0 as? ChatClientError, .rateLimited)
        }
        XCTAssertThrowsError(try ChatClient.parseReply(data: Data(), status: 502)) {
            XCTAssertEqual($0 as? ChatClientError, .network)
        }
        XCTAssertThrowsError(try ChatClient.parseReply(data: Data(#"{"reply":"  "}"#.utf8), status: 200)) {
            XCTAssertEqual($0 as? ChatClientError, .badReply)
        }
        XCTAssertThrowsError(try ChatClient.parseReply(data: Data("nope".utf8), status: 200)) {
            XCTAssertEqual($0 as? ChatClientError, .badReply)
        }
    }

    func testChatIsOffUntilConfigured() {
        // Config ships empty on purpose; deploying the proxy fills it in.
        if Config.chatEndpoint.isEmpty {
            XCTAssertFalse(Config.isChatConfigured)
        }
    }
}

final class WeekShareTextTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        return c
    }()

    private func day(_ d: Int, mood: Int?, meals: Int, higher: Int) -> DaySummary {
        DaySummary(day: calendar.date(from: DateComponents(year: 2026, month: 10, day: d))!,
                   moodLevel: mood, mealCount: meals, higherCount: higher,
                   worstMeal: higher > 0 ? .higher : (meals > 0 ? .lower : nil))
    }

    func testOldestFirstWithHeaderAndFooter() {
        let text = WeekShareText.build([day(30, mood: 1, meals: 2, higher: 1), day(29, mood: nil, meals: 0, higher: 0)],
                                       alertCount: 0, calendar: calendar)
        let lines = text.components(separatedBy: "\n")
        XCTAssertEqual(lines.first, Str.shareHeader)
        XCTAssertEqual(lines.last, Str.shareFooter)
        XCTAssertTrue(lines[1].hasPrefix("10月29日"))
        XCTAssertTrue(lines[2].hasPrefix("10月30日"))
        XCTAssertTrue(lines[2].contains(Str.highFoodNote))
        XCTAssertTrue(lines[1].contains(Str.noMood))
    }

    func testAlertLineOnlyWhenAlertsExist() {
        let days = [day(30, mood: 0, meals: 1, higher: 0)]
        XCTAssertFalse(WeekShareText.build(days, alertCount: 0, calendar: calendar).contains("求助或提醒"))
        XCTAssertTrue(WeekShareText.build(days, alertCount: 2, calendar: calendar).contains(Str.shareAlerts(2)))
    }
}

final class DemoDataTests: XCTestCase {
    func testPlanCoversSevenDaysAndHasHigherFood() {
        XCTAssertEqual(Set(DemoData.plan.map(\.daysAgo)), Set(0...6))
        XCTAssertTrue(DemoData.plan.contains { $0.meals.contains { $0.1 == .higher } })
    }

    func testLoadThenClearLeavesRealEntries() throws {
        let container = try ModelContainer(for: MealEntry.self, MoodEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.insert(MealEntry(source: "label", name: "real", rating: "lower"))
        DemoData.load(into: context)
        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<MealEntry>()), 1)
        DemoData.clear(from: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 0)
    }
}
