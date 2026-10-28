import Foundation

enum DistressLevel: Equatable {
    case none
    /// Sadness, loneliness or worry: the chat answers gently and offers a call.
    case concern
    /// Possible self-harm or a medical emergency: the call screen opens at once and nothing is sent to the network.
    case urgent(CallReason)
}

/// Looks for distress words in what the user types or says. Runs on the phone, with no network,
/// and always before any text is sent to the language model.
///
/// It is deliberately cautious: a false alarm costs one tap to dismiss, a missed alert costs more.
/// The word lists are a starting point. A nurse must review them, and every trigger is logged so
/// they can be tuned. A model may be added later to catch more, but never to remove an alert.
enum DistressDetector {
    /// Possible self-harm. Cantonese, Traditional and Simplified Chinese, English.
    static let selfHarmPhrases: [String] = [
        "想死", "唔想活", "不想活", "唔想再活", "自殺", "自杀", "輕生", "轻生",
        "結束生命", "结束生命", "了結自己", "傷害自己", "伤害自己", "死咗好", "死咗算",
        "活唔落去", "活不下去", "想結束一切", "想结束一切", "食晒啲藥", "食晒所有藥", "飲晒啲藥",
        "suicide", "kill myself", "end my life", "want to die", "wanna die", "hurt myself",
        "don't want to live", "dont want to live"
    ]

    /// Possible medical emergency.
    static let medicalPhrases: [String] = [
        "胸口痛", "心口痛", "胸口翳", "唔夠氣", "透唔到氣", "喘唔到氣", "呼吸困難", "呼吸唔到",
        "暈低", "暈倒", "跌低", "跌倒咗", "跌咗落地", "中風", "心臟病發", "口歪", "手腳冇力",
        "冇力郁", "嘔血", "流血唔止",
        "chest pain", "can't breathe", "cant breathe", "cannot breathe", "heart attack", "stroke",
        "fell down", "passed out", "fainted"
    ]

    /// Sadness, loneliness, worry.
    static let concernPhrases: [String] = [
        "好孤獨", "好孤单", "好孤單", "好寂寞", "冇人理", "冇人關心", "好辛苦", "好痛苦",
        "好攰", "成日喊", "喊咗", "好驚", "好無助", "唔開心", "好傷心", "冇希望", "冇用",
        "lonely", "hopeless", "so sad", "depressed", "anxious", "scared"
    ]

    static func evaluate(_ text: String) -> DistressLevel {
        let n = TextNormalizer.normalize(text)
        guard !n.isEmpty else { return .none }

        if selfHarmPhrases.contains(where: { n.contains(TextNormalizer.normalize($0)) }) {
            return .urgent(.distressWords)
        }
        if medicalPhrases.contains(where: { n.contains(TextNormalizer.normalize($0)) }) {
            return .urgent(.medicalEmergency)
        }
        if concernPhrases.contains(where: { n.contains(TextNormalizer.normalize($0)) }) {
            return .concern
        }
        return .none
    }
}

enum TextNormalizer {
    /// Lower-cases and removes spaces and punctuation, so "Kill  myself!" and "想 死" still match.
    static func normalize(_ text: String) -> String {
        String(text.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation })
    }
}
