import Foundation

/// Cantonese wording for the pick-a-food list. Needs review by a native speaker and a dietitian.
extension Str {
    static let mealListTitle = "揀食物"
    static let mealListSpoken = "請按你食嘅嘢。清單分咗類，下面仲有好多款。"
    static let mealPickAnother = "再揀一樣"
    static let mealEstimate = "呢個只係估算。每間餐廳嘅份量同味道都唔同。"
    static let mealResultTitle = "估算結果"
    static let milliliter = "毫升"

    static func servingLine(_ dish: Dish) -> String {
        let unit = dish.isDrink ? milliliter : unitG
        return "一份大約\(Narration.number(dish.servingAmount))\(unit)，約\(Narration.number(dish.servingKcal))\(unitKcal)，碳水化合物\(Narration.number(dish.servingCarbsG))\(unitG)。"
    }

    static func mealSpokenResult(_ dish: Dish, assessment: NutritionAssessment) -> String {
        var parts = ["\(dish.name)。"]
        let basis = Narration.basisPhrase(dish.facts.basis)
        if let level = assessment.sugar {
            parts.append("\(basis)有糖\(Narration.number(dish.sugarsPer100))克，\(Narration.levelWord(level))。")
        }
        if let level = assessment.sodium {
            parts.append("鈉\(Narration.number(dish.sodiumMgPer100))毫克，\(Narration.levelWord(level))。")
        }
        switch assessment.overall {
        case .higher: parts.append(tipHigher)
        case .middle: parts.append(tipMiddle)
        case .lower: parts.append(tipLower)
        case nil: break
        }
        parts.append(servingLine(dish))
        parts.append(mealEstimate)
        return parts.joined()
    }
}
