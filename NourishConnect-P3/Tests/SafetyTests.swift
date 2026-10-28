import XCTest
@testable import NourishConnect

final class DistressDetectorTests: XCTestCase {
    func testSelfHarmWordsAreUrgent() {
        for text in ["我想死", "我唔想活喇", "我想自殺", "I want to die", "Kill  myself!", "想 死"] {
            XCTAssertEqual(DistressDetector.evaluate(text), .urgent(.distressWords), text)
        }
    }

    func testMedicalWordsAreUrgentMedical() {
        for text in ["我今日胸口痛", "我跌低咗", "I can't breathe", "chest pain"] {
            XCTAssertEqual(DistressDetector.evaluate(text), .urgent(.medicalEmergency), text)
        }
    }

    func testSelfHarmWinsWhenBothAppear() {
        XCTAssertEqual(DistressDetector.evaluate("我跌低咗，想死"), .urgent(.distressWords))
    }

    func testSadnessIsConcernNotUrgent() {
        XCTAssertEqual(DistressDetector.evaluate("我好孤單"), .concern)
        XCTAssertEqual(DistressDetector.evaluate("I feel lonely"), .concern)
    }

    func testOrdinaryTalkIsNone() {
        for text in ["今日食咗碗麵", "笑死我", "今日天氣好好", ""] {
            XCTAssertEqual(DistressDetector.evaluate(text), .none, text)
        }
    }
}

final class MoodRulesTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        return c
    }()

    private func now() -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
    }

    private func entry(daysAgo: Int, hour: Int = 9, level: Int) -> (date: Date, level: Int) {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now()))!
        return (calendar.date(byAdding: .hour, value: hour, to: day)!, level)
    }

    private func action(_ entries: [(date: Date, level: Int)]) -> MoodAction {
        MoodRules.action(entries: entries, now: now(), calendar: calendar)
    }

    func testNoEntriesNothing() {
        XCTAssertEqual(action([]), .none)
    }

    func testOneNotWellOffersSupport() {
        XCTAssertEqual(action([entry(daysAgo: 0, level: 2)]), .offerSupport)
    }

    func testTwoTapsOnOneDayDoNotAlert() {
        XCTAssertEqual(action([entry(daysAgo: 0, hour: 9, level: 2), entry(daysAgo: 0, hour: 10, level: 2)]),
                       .offerSupport)
    }

    func testNotWellOnTwoDaysAlerts() {
        XCTAssertEqual(action([entry(daysAgo: 1, level: 2), entry(daysAgo: 0, level: 2)]), .alert)
    }

    func testOldNotWellOutsideWindowIsIgnored() {
        XCTAssertEqual(action([entry(daysAgo: 3, level: 2), entry(daysAgo: 0, level: 2)]), .offerSupport)
    }

    func testLonelyOnAllThreeDaysAlerts() {
        XCTAssertEqual(action([entry(daysAgo: 2, level: 1), entry(daysAgo: 1, level: 1), entry(daysAgo: 0, level: 1)]),
                       .alert)
    }

    func testLonelyOnTwoDaysDoesNot() {
        XCTAssertEqual(action([entry(daysAgo: 1, level: 1), entry(daysAgo: 0, level: 1)]), .none)
    }

    func testOkayAfterNotWellIsNone() {
        XCTAssertEqual(action([entry(daysAgo: 1, level: 2), entry(daysAgo: 0, level: 0)]), .none)
    }

    func testMixedLowDaysAlert() {
        XCTAssertEqual(action([entry(daysAgo: 2, level: 1), entry(daysAgo: 1, level: 2), entry(daysAgo: 0, level: 1)]),
                       .alert)
    }
}

final class ReplyFilterTests: XCTestCase {
    func testMedicationAndDiagnosisQuestionsAreCaughtBeforeTheModel() {
        XCTAssertEqual(InputGuard.classify("我可以唔食藥嗎"), .medication)
        XCTAssertEqual(InputGuard.classify("How much insulin should I take"), .medication)
        XCTAssertEqual(InputGuard.classify("我想打針"), .medication)
        XCTAssertEqual(InputGuard.classify("我係咪有抑鬱症"), .diagnosis)
        XCTAssertEqual(InputGuard.classify("今日食咩好"), .ok)
    }

    func testBlocksMedicationAndDiagnosisInReplies() {
        for reply in ["你應該加藥", "Take your medication", "你可能有抑鬱症", "我係醫生", "I am a doctor"] {
            XCTAssertEqual(ReplyFilter.check(reply), .blocked, reply)
        }
    }

    func testBlocksPhoneNumbersAndLinks() {
        XCTAssertEqual(ReplyFilter.check("請打 2389 2222 搵人"), .blocked)
        XCTAssertEqual(ReplyFilter.check("睇下 https://example.com"), .blocked)
    }

    func testAllowsPlainSupportiveReplies() {
        XCTAssertEqual(ReplyFilter.check("你可以試下做個呼吸練習。"), .ok("你可以試下做個呼吸練習。"))
        XCTAssertEqual(ReplyFilter.check("如果好緊急，可以打999"), .ok("如果好緊急，可以打999"))
        XCTAssertEqual(ReplyFilter.check("糖12.5克偏高"), .ok("糖12.5克偏高"))
    }

    func testBlocksEmptyReply() {
        XCTAssertEqual(ReplyFilter.check("   "), .blocked)
    }

    func testLongReplyIsCutAtASentenceEnd() {
        let sentence = "多啲同朋友傾偈，會舒服啲。"
        let long = String(repeating: sentence, count: 30)
        guard case let .ok(text) = ReplyFilter.check(long) else { return XCTFail("expected ok") }
        XCTAssertLessThanOrEqual(text.count, ReplyFilter.maxLength)
        XCTAssertTrue(text.hasSuffix("。"))
    }
}

final class CallTargetTests: XCTestCase {
    private let contacts = [
        CallTarget(id: "contact-0", name: "女兒", phone: "91234567", kind: .contact),
        CallTarget(id: "contact-1", name: "社工", phone: "98765432", kind: .contact)
    ]

    func testDistressOrderIsContactsThenCrisisThenEmergency() {
        let ids = CrisisLines.targets(for: .distressWords, contacts: contacts).map(\.id)
        XCTAssertEqual(ids, ["contact-0", "contact-1", "crisis-ha", "crisis-befrienders", "crisis-sps", "emergency-999"])
    }

    func testMedicalEmergencyPutsNineNineNineFirst() {
        let ids = CrisisLines.targets(for: .medicalEmergency, contacts: contacts).map(\.id)
        XCTAssertEqual(ids.first, "emergency-999")
        XCTAssertEqual(ids.count, 3)
    }

    func testHelpButtonShowsContactsThenEmergency() {
        let ids = CrisisLines.targets(for: .helpButton, contacts: contacts).map(\.id)
        XCTAssertEqual(Array(ids.prefix(3)), ["contact-0", "contact-1", "emergency-999"])
    }

    func testNoContactsStillGivesHelp() {
        XCTAssertFalse(CrisisLines.targets(for: .moodPattern, contacts: []).isEmpty)
    }

    func testEmergencyHoldIsShorter() {
        XCTAssertLessThan(CrisisLines.emergency.holdSeconds, contacts[0].holdSeconds)
    }
}
