import Foundation

/// Cantonese wording for the meal-photo feature. Needs review by a native speaker and a dietitian.
extension Str {
    static let mealTitle = "影整餐嘢"
    static let mealSpoken = "影一張你食緊嘅嘢，我幫你估下係咩。你都可以直接喺清單揀。"
    static let mealThinking = "等一等，我睇緊張相。"
    static let mealYes = "係"
    static let mealNo = "唔係"
    static let mealChoose = "你食嘅係邊樣？"
    static let mealChooseList = "都唔係，睇晒清單"
    static let mealPickList = "喺清單揀食物"
    static let mealNoModel = "相機暫時認唔到食物。請喺清單揀你食嘅嘢。"
    static let mealNoMatch = "我認唔到呢張相。請再影一次，或者喺清單揀。"
    static let mealListTitle = "揀食物"
    static let mealListSpoken = "請按你食嘅嘢。"
    static let mealEstimate = "呢個只係估算。每間餐廳嘅份量同味道都唔同。"
    static let mealPhotoNotKept = "張相只喺電話入面睇，唔會儲存，亦都唔會傳出去。"
    static let mealResultTitle = "估算結果"
    static let milliliter = "毫升"

    static func mealAsk(_ name: String) -> String {
        "係唔係「\(name)」？"
    }

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
