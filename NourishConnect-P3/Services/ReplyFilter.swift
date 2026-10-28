import Foundation

/// Checks what the user typed before it goes to the language model.
/// Medication and diagnosis questions never reach the model: they get a fixed reply.
enum InputGuard {
    enum Kind: Equatable {
        case ok
        case medication
        case diagnosis
    }

    static let medicationTerms: [String] = [
        "藥", "药", "胰島素", "胰岛素", "打針", "劑量", "剂量", "食幾多粒",
        "medication", "insulin", "dose", "dosage", "pill", "tablet"
    ]

    static let diagnosisTerms: [String] = [
        "抑鬱症", "抑郁症", "焦慮症", "焦虑症", "精神病", "憂鬱症", "係咪有病",
        "diagnos", "depression"
    ]

    static func classify(_ text: String) -> Kind {
        let n = TextNormalizer.normalize(text)
        if medicationTerms.contains(where: { n.contains(TextNormalizer.normalize($0)) }) {
            return .medication
        }
        if diagnosisTerms.contains(where: { n.contains(TextNormalizer.normalize($0)) }) {
            return .diagnosis
        }
        return .ok
    }
}

enum FilterResult: Equatable {
    case ok(String)
    case blocked
}

/// Checks what the language model sent back. Anything about medication, doses, diagnosis, or
/// claiming to be a person, doctor or nurse is blocked, as is any phone number or web address
/// (the app shows only numbers it was given). A blocked reply is replaced by a fixed safe message.
enum ReplyFilter {
    static let blockedTerms: [String] = [
        "藥", "药", "胰島素", "胰岛素", "劑量", "剂量", "服用",
        "診斷", "诊断", "確診", "确诊", "抑鬱症", "抑郁症", "焦慮症", "焦虑症", "精神病", "憂鬱症",
        "血糖會", "預測", "预测",
        "我係醫生", "我係護士", "我係真人", "我是醫生", "我是護士", "我是真人",
        "medication", "insulin", "dosage", "dose", "diagnos", "prescri", "antidepress",
        "iamadoctor", "iamanurse", "iamhuman"
    ]

    static let maxLength = 160

    static func check(_ reply: String) -> FilterResult {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .blocked }

        let n = TextNormalizer.normalize(trimmed)
        if blockedTerms.contains(where: { n.contains(TextNormalizer.normalize($0)) }) {
            return .blocked
        }
        // Five or more digits in a row (after removing spaces and dashes) looks like a phone number.
        if n.range(of: #"\d{5,}"#, options: .regularExpression) != nil {
            return .blocked
        }
        if n.contains("http") || n.contains("www") {
            return .blocked
        }
        return .ok(shorten(trimmed))
    }

    /// Keeps a reply short enough to read aloud, cutting at a sentence end where possible.
    static func shorten(_ text: String) -> String {
        guard text.count > maxLength else { return text }
        let head = String(text.prefix(maxLength))
        let enders: [Character] = ["。", "！", "？", ".", "!", "?"]
        if let cut = head.lastIndex(where: { enders.contains($0) }) {
            return String(head[...cut])
        }
        return head
    }
}
