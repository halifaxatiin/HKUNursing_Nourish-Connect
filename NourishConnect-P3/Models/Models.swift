import Foundation
import SwiftData

/// One record holding the user's display and voice preferences.
/// RootView makes sure exactly one exists.
@Model
final class UserSettings {
    /// Text size multiplier, 1.0 (normal) to 2.0 (double).
    var textScale: Double
    var highContrast: Bool
    var speechEnabled: Bool
    /// AVSpeechUtterance rate, 0.0 to 1.0. 0.5 is Apple's default.
    var speechRate: Double

    init(textScale: Double = 1.4,
         highContrast: Bool = false,
         speechEnabled: Bool = true,
         speechRate: Double = 0.42) {
        self.textScale = textScale
        self.highContrast = highContrast
        self.speechEnabled = speechEnabled
        self.speechRate = speechRate
    }
}

/// A person the user can call for help (family, community worker, crisis service).
@Model
final class EmergencyContact {
    var name: String
    var phone: String
    /// Lower number = shown first.
    var priority: Int

    init(name: String, phone: String, priority: Int) {
        self.name = name
        self.phone = phone
        self.priority = priority
    }
}

/// A saved meal or product result. Filled in from phase 2 onwards.
@Model
final class MealEntry {
    var date: Date
    /// "barcode", "label" or "meal"
    var source: String
    var name: String
    /// "lower", "middle" or "higher"
    var rating: String
    var note: String

    init(date: Date = .now, source: String, name: String, rating: String, note: String = "") {
        self.date = date
        self.source = source
        self.name = name
        self.rating = rating
        self.note = note
    }
}

/// A mood check result. Filled in from phase 3 onwards.
@Model
final class MoodEntry {
    var date: Date
    /// 0 = okay, 1 = a bit lonely, 2 = not well
    var level: Int
    /// "tap" or "voice"
    var source: String

    init(date: Date = .now, level: Int, source: String = "tap") {
        self.date = date
        self.level = level
        self.source = source
    }
}

/// A finished or stopped wellbeing exercise (breathing). Logs completion only.
@Model
final class WellbeingSession {
    var date: Date
    /// "breathing"
    var activity: String
    var seconds: Int

    init(date: Date = .now, activity: String, seconds: Int) {
        self.date = date
        self.activity = activity
        self.seconds = seconds
    }
}

/// A record that an alert was raised.
@Model
final class AlertEvent {
    var date: Date
    /// What caused it, e.g. "help button", "mood not well", "distress words"
    var trigger: String
    /// What the app did, e.g. "call screen shown", "called contact"
    var action: String

    init(date: Date = .now, trigger: String, action: String) {
        self.date = date
        self.trigger = trigger
        self.action = action
    }
}
