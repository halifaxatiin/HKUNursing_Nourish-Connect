import Foundation

/// Why the call screen was opened. Saved as text in AlertEvent.trigger.
enum CallReason: String, Identifiable, Hashable {
    case helpButton
    case moodNotWell
    case moodPattern
    case distressWords
    case medicalEmergency

    var id: String { rawValue }
    var logKey: String { rawValue }

    /// What is read aloud when the call screen opens.
    var spoken: String {
        switch self {
        case .helpButton: return Str.callPromptHelp
        case .moodNotWell, .moodPattern, .distressWords: return Str.callPromptDistress
        case .medicalEmergency: return Str.callPromptMedical
        }
    }
}

/// Someone the user can call from the call screen.
struct CallTarget: Identifiable, Hashable {
    enum Kind: Hashable {
        case emergency
        case contact
        case crisis
    }

    let id: String
    let name: String
    let phone: String
    let kind: Kind

    /// "9123 4567" for an 8-digit number, otherwise as saved.
    var displayPhone: String {
        let digits = phone.filter(\.isNumber)
        guard digits.count == 8, digits == phone else { return phone }
        return "\(digits.prefix(4)) \(digits.suffix(4))"
    }

    /// How long the button must be held before the call starts. Shorter for 999.
    /// To be tuned with the user in testing: long enough to stop accidents, short enough for shaky hands.
    var holdSeconds: Double {
        kind == .emergency ? 1.0 : 1.5
    }
}

/// Hong Kong emergency and 24-hour crisis numbers, from Mind HK's "Find help now" list
/// (https://www.mind.org.hk/resources/find-help-now/). A nurse or social worker must confirm the
/// numbers are current and choose which ones to show before real use.
/// The Government Mental Health Support Hotline (18111) is left out until its number is confirmed:
/// the source page listed it two different ways.
enum CrisisLines {
    static let emergency = CallTarget(id: "emergency-999", name: Str.emergencyName, phone: "999", kind: .emergency)

    static let crisis: [CallTarget] = [
        CallTarget(id: "crisis-ha", name: Str.haMentalHealthName, phone: "24667350", kind: .crisis),
        CallTarget(id: "crisis-befrienders", name: Str.befriendersName, phone: "23892222", kind: .crisis),
        CallTarget(id: "crisis-sps", name: Str.spsName, phone: "23820000", kind: .crisis)
    ]

    /// The order shown on the call screen. The user's own contacts (already in their saved order)
    /// come first, then crisis lines, then 999. For a medical emergency 999 comes first.
    static func targets(for reason: CallReason, contacts: [CallTarget]) -> [CallTarget] {
        switch reason {
        case .medicalEmergency:
            return [emergency] + contacts
        case .helpButton:
            return contacts + [emergency] + crisis
        case .moodNotWell, .moodPattern, .distressWords:
            return contacts + crisis + [emergency]
        }
    }
}
