import Foundation

/// Turns text read from a Hong Kong "1+7" nutrition label (Chinese and English)
/// into NutritionFacts. Pure logic with no camera or network, so it is unit tested.
///
/// Rules that keep it safe:
/// - A value that cannot be read is nil, never a guess.
/// - If the label lists both "per serving" and "per 100 g" columns, a row must show two
///   numbers or it is skipped, so a serving value is never taken for a per-100 g value.
/// - Percent figures (NRV columns) are ignored.
enum LabelParser {
    private enum Nutrient {
        case transFat, satFat, fat, protein, carbs, sugars, sodium, salt, energy
    }

    /// Checked in this order, so "saturated fat" is not mistaken for "fat".
    private static let keywords: [(Nutrient, [String])] = [
        (.transFat, ["反式脂肪", "trans fat", "trans-fat", "transfat"]),
        (.satFat, ["飽和脂肪", "饱和脂肪", "saturated", "sat. fat", "sat fat"]),
        (.fat, ["總脂肪", "总脂肪", "脂肪", "total fat", "fat"]),
        (.protein, ["蛋白質", "蛋白质", "protein"]),
        (.carbs, ["碳水化合物", "carbohydrate", "carbs"]),
        (.sugars, ["總糖", "糖", "sugars", "sugar"]),
        (.sodium, ["鈉", "钠", "sodium"]),
        (.salt, ["鹽", "盐", "salt"]),
        (.energy, ["能量", "熱量", "热量", "energy", "calories"])
    ]

    private struct Reading {
        let value: Double
        let unit: String
    }

    private struct ColumnPlan {
        let basis: NutritionBasis
        /// Which number in a row belongs to the per-100 column. 0 = first.
        let index: Int
        /// True when the label mentions both a serving and a 100 g/ml column.
        let twoColumns: Bool
    }

    static func parse(_ text: String) -> NutritionFacts {
        let plan = columnPlan(for: text)
        var facts = NutritionFacts()
        facts.basis = plan.basis

        for row in text.components(separatedBy: .newlines) {
            let lower = row.lowercased()
            guard let (nutrient, afterKeyword) = match(lower) else { continue }
            let readings = readings(in: afterKeyword)
            guard !readings.isEmpty else { continue }

            switch nutrient {
            case .energy:
                if facts.energyKcal == nil { facts.energyKcal = pickEnergy(readings, plan: plan) }
            default:
                guard let reading = pick(readings, plan: plan) else { continue }
                apply(reading, to: nutrient, in: &facts)
            }
        }
        return facts
    }

    // MARK: Rows

    private static func match(_ lowerRow: String) -> (Nutrient, String)? {
        for (nutrient, words) in keywords {
            for word in words {
                if let range = lowerRow.range(of: word) {
                    return (nutrient, String(lowerRow[range.upperBound...]))
                }
            }
        }
        return nil
    }

    private static let numberPattern = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*(mg|毫克|kcal|千卡|大卡|kj|千焦|g|克)?\s*(%)?"#,
        options: [.caseInsensitive]
    )

    private static func readings(in text: String) -> [Reading] {
        let ns = text as NSString
        let matches = numberPattern.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var result: [Reading] = []
        for m in matches {
            // Skip percentages such as "15%".
            if m.range(at: 3).location != NSNotFound { continue }
            guard let value = Double(ns.substring(with: m.range(at: 1))) else { continue }
            let unit = m.range(at: 2).location != NSNotFound
                ? ns.substring(with: m.range(at: 2)).lowercased()
                : ""
            result.append(Reading(value: value, unit: unit))
        }
        return result
    }

    private static func pick(_ readings: [Reading], plan: ColumnPlan) -> Reading? {
        if plan.twoColumns {
            return readings.count > plan.index && readings.count >= 2 ? readings[plan.index] : nil
        }
        return readings.first
    }

    private static func pickEnergy(_ readings: [Reading], plan: ColumnPlan) -> Double? {
        let kcal = readings.filter { ["kcal", "千卡", "大卡"].contains($0.unit) }
        if let r = pick(kcal, plan: plan) { return r.value }
        let kj = readings.filter { ["kj", "千焦"].contains($0.unit) }
        if let r = pick(kj, plan: plan) { return r.value / 4.184 }
        return nil
    }

    private static func apply(_ reading: Reading, to nutrient: Nutrient, in facts: inout NutritionFacts) {
        let isMilligram = ["mg", "毫克"].contains(reading.unit)
        let grams = isMilligram ? reading.value / 1000 : reading.value

        switch nutrient {
        case .transFat: if facts.transFatG == nil { facts.transFatG = grams }
        case .satFat: if facts.satFatG == nil { facts.satFatG = grams }
        case .fat: if facts.fatG == nil { facts.fatG = grams }
        case .protein: if facts.proteinG == nil { facts.proteinG = grams }
        case .carbs: if facts.carbsG == nil { facts.carbsG = grams }
        case .sugars: if facts.sugarsG == nil { facts.sugarsG = grams }
        case .sodium:
            // Unit g or 克 means grams; mg, 毫克 or no unit means milligrams.
            let mg = ["g", "克"].contains(reading.unit) ? reading.value * 1000 : reading.value
            if facts.sodiumMg == nil { facts.sodiumMg = mg }
        case .salt:
            // Salt (sodium chloride) is about 40% sodium.
            let saltGrams = isMilligram ? reading.value / 1000 : reading.value
            if facts.sodiumMg == nil { facts.sodiumMg = saltGrams * 400 }
        case .energy:
            break
        }
    }

    // MARK: Columns

    private static func columnPlan(for text: String) -> ColumnPlan {
        let lower = text.lowercased()
        let per100 = lower.range(of: #"100\s*(g|克|ml|毫升)"#, options: .regularExpression)
        let serving = lower.range(of: #"serving|每份|每包|每件|per portion|per pack"#, options: .regularExpression)

        func per100Basis(_ range: Range<String.Index>) -> NutritionBasis {
            let found = lower[range]
            return (found.contains("ml") || found.contains("毫升")) ? .per100ml : .per100g
        }

        switch (per100, serving) {
        case let (p?, s?):
            return ColumnPlan(basis: per100Basis(p),
                              index: p.lowerBound < s.lowerBound ? 0 : 1,
                              twoColumns: true)
        case let (p?, nil):
            return ColumnPlan(basis: per100Basis(p), index: 0, twoColumns: false)
        case (nil, _?):
            return ColumnPlan(basis: .perServing, index: 0, twoColumns: false)
        case (nil, nil):
            return ColumnPlan(basis: .unknown, index: 0, twoColumns: false)
        }
    }
}
