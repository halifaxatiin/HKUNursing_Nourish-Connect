import Foundation

/// Builds the Cantonese sentences read aloud on the result screen, from fixed templates.
/// No language model is involved in phase 2. The tips here are generic and must be
/// reviewed and approved by a nurse or dietitian before real use.
enum Narration {
    /// 12.0 becomes "12", 12.46 becomes "12.5".
    static func number(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    static func levelWord(_ level: Level) -> String {
        switch level {
        case .lower: return Str.levelLow
        case .middle: return Str.levelMid
        case .higher: return Str.levelHigh
        }
    }

    /// "每100克", "每100毫升" or "每份".
    static func basisPhrase(_ basis: NutritionBasis) -> String {
        switch basis {
        case .per100g: return Str.per100g
        case .per100ml: return Str.per100ml
        case .perServing: return Str.perServing
        case .unknown: return ""
        }
    }

    static func spoken(outcome: ScanOutcome, assessment: NutritionAssessment) -> String {
        let facts = outcome.facts
        var parts: [String] = []

        if let name = outcome.productName {
            parts.append("\(name)。")
        }

        guard let overall = assessment.overall else {
            parts.append(facts.basis == .perServing ? Str.perServingNote : Str.unratedNote)
            return parts.joined()
        }

        let basis = basisPhrase(facts.basis)
        if let level = assessment.sugar, let sugar = facts.sugarsG {
            parts.append("\(basis)有糖\(number(sugar))克，\(levelWord(level))。")
        }
        if let level = assessment.sodium, let sodium = facts.sodiumMg {
            parts.append("鈉\(number(sodium))毫克，\(levelWord(level))。")
        }

        switch overall {
        case .higher: parts.append(Str.tipHigher)
        case .middle: parts.append(Str.tipMiddle)
        case .lower: parts.append(Str.tipLower)
        }

        if facts.carbsG != nil {
            parts.append(Str.carbsNote)
        }
        parts.append(Str.checkPackage)
        return parts.joined()
    }
}
