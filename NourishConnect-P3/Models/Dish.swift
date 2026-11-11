import Foundation

/// The groups shown on the pick-a-food screen, in the order they appear.
enum DishCategory: String, CaseIterable, Identifiable {
    case rice, noodles, congee, dimSum, dishes, bakery, fruit, drinks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rice: return "飯"
        case .noodles: return "粉麵"
        case .congee: return "粥"
        case .dimSum: return "點心"
        case .dishes: return "餸菜"
        case .bakery: return "麵包糕點"
        case .fruit: return "生果"
        case .drinks: return "飲品"
        }
    }
}

/// One dish the user can pick from the food list. The app does not recognise food from photos:
/// the user always chooses the dish.
///
/// ALL NUMBERS BELOW ARE PLACEHOLDER ESTIMATES for a typical Hong Kong restaurant serving.
/// A dietitian must replace them with values from a trusted source (for example the Centre for Food
/// Safety's nutrient information) before any real use. Sugar and sodium are per 100 g (or 100 ml for
/// drinks) so the same traffic-light rules as packaged food apply. Energy and carbohydrate are per
/// typical serving and are shown but not rated.
struct Dish: Identifiable, Hashable {
    let id: String
    let name: String
    let category: DishCategory
    var isDrink: Bool { category == .drinks }
    let sugarsPer100: Double
    let sodiumMgPer100: Double
    /// Typical serving size in grams (millilitres for drinks).
    let servingAmount: Double
    let servingKcal: Double
    let servingCarbsG: Double

    var facts: NutritionFacts {
        NutritionFacts(basis: isDrink ? .per100ml : .per100g,
                       sugarsG: sugarsPer100,
                       sodiumMg: sodiumMgPer100)
    }
}

enum DishCatalog {
    static func dish(id: String) -> Dish? {
        all.first { $0.id == id }
    }

    /// The dishes of one group, in list order.
    static func dishes(in category: DishCategory) -> [Dish] {
        all.filter { $0.category == category }
    }

    /// Groups that have at least one dish, in display order.
    static var sections: [(category: DishCategory, dishes: [Dish])] {
        DishCategory.allCases
            .map { (category: $0, dishes: dishes(in: $0)) }
            .filter { !$0.dishes.isEmpty }
    }

    private static func food(_ id: String, _ name: String, _ category: DishCategory, sugar: Double,
                             sodium: Double, grams: Double, kcal: Double, carbs: Double) -> Dish {
        Dish(id: id, name: name, category: category, sugarsPer100: sugar, sodiumMgPer100: sodium,
             servingAmount: grams, servingKcal: kcal, servingCarbsG: carbs)
    }

    private static func drink(_ id: String, _ name: String, sugar: Double,
                              ml: Double, kcal: Double, carbs: Double) -> Dish {
        Dish(id: id, name: name, category: .drinks, sugarsPer100: sugar, sodiumMgPer100: 0,
             servingAmount: ml, servingKcal: kcal, servingCarbsG: carbs)
    }

    static let all: [Dish] = [
        food("steamed_rice", "白飯", .rice, sugar: 0.1, sodium: 2, grams: 200, kcal: 260, carbs: 57),
        food("char_siu_rice", "叉燒飯", .rice, sugar: 4, sodium: 450, grams: 400, kcal: 750, carbs: 100),
        food("roast_goose_rice", "燒鵝飯", .rice, sugar: 2, sodium: 400, grams: 400, kcal: 850, carbs: 85),
        food("soy_chicken_rice", "油雞飯", .rice, sugar: 2, sodium: 420, grams: 400, kcal: 700, carbs: 85),
        food("wonton_noodles", "雲吞麵", .noodles, sugar: 0.5, sodium: 380, grams: 450, kcal: 400, carbs: 55),
        food("beef_brisket_noodles", "牛腩麵", .noodles, sugar: 1, sodium: 400, grams: 500, kcal: 550, carbs: 65),
        food("beef_hofun", "乾炒牛河", .noodles, sugar: 1, sodium: 450, grams: 400, kcal: 800, carbs: 95),
        food("singapore_noodles", "星洲炒米", .noodles, sugar: 2, sodium: 480, grams: 400, kcal: 750, carbs: 90),
        food("instant_noodle_luncheon", "餐蛋麵", .noodles, sugar: 2, sodium: 550, grams: 350, kcal: 600, carbs: 60),
        food("rice_roll", "腸粉", .dimSum, sugar: 2, sodium: 300, grams: 150, kcal: 200, carbs: 35),
        food("har_gow", "蝦餃", .dimSum, sugar: 0.5, sodium: 350, grams: 100, kcal: 150, carbs: 18),
        food("siu_mai", "燒賣", .dimSum, sugar: 1, sodium: 450, grams: 100, kcal: 200, carbs: 12),
        food("char_siu_bun", "叉燒包", .dimSum, sugar: 12, sodium: 300, grams: 120, kcal: 270, carbs: 40),
        food("vegetable_congee", "菜肉粥", .congee, sugar: 0.2, sodium: 180, grams: 400, kcal: 200, carbs: 35),
        food("century_egg_congee", "皮蛋瘦肉粥", .congee, sugar: 0.2, sodium: 250, grams: 400, kcal: 220, carbs: 33),
        food("steamed_fish", "蒸魚", .dishes, sugar: 0.5, sodium: 350, grams: 150, kcal: 150, carbs: 2),
        food("stir_fried_vegetables", "炒菜", .dishes, sugar: 2, sodium: 300, grams: 150, kcal: 90, carbs: 8),
        food("blanched_choy_sum", "白灼菜心", .dishes, sugar: 1.5, sodium: 200, grams: 150, kcal: 50, carbs: 6),
        food("toast_butter", "牛油多士", .bakery, sugar: 4, sodium: 450, grams: 80, kcal: 250, carbs: 28),
        food("pineapple_bun_butter", "菠蘿油", .bakery, sugar: 15, sodium: 300, grams: 140, kcal: 450, carbs: 55),
        food("french_toast", "西多士", .bakery, sugar: 8, sodium: 300, grams: 150, kcal: 450, carbs: 40),
        food("egg_tart", "蛋撻", .bakery, sugar: 14, sodium: 120, grams: 90, kcal: 230, carbs: 25),
        food("fruit", "生果", .fruit, sugar: 10, sodium: 2, grams: 150, kcal: 70, carbs: 17),
        drink("hk_milk_tea", "港式奶茶", sugar: 5, ml: 250, kcal: 140, carbs: 22),
        drink("lemon_tea_iced", "凍檸茶", sugar: 7, ml: 350, kcal: 110, carbs: 28)
    ]
}
