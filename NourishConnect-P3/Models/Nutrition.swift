import Foundation

/// What the nutrient numbers on a label or database entry are measured against.
enum NutritionBasis: String, Hashable {
    case per100g
    case per100ml
    case perServing
    case unknown
}

/// Traffic-light level for one nutrient. Lower is better.
enum Level: Int, Comparable, Hashable {
    case lower = 0
    case middle = 1
    case higher = 2

    static func < (lhs: Level, rhs: Level) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Reads back the text saved in MealEntry.rating. "unrated" and anything else gives nil.
    init?(storageKey: String) {
        switch storageKey {
        case "lower": self = .lower
        case "middle": self = .middle
        case "higher": self = .higher
        default: return nil
        }
    }

    /// Stable text used when saving to MealEntry.
    var storageKey: String {
        switch self {
        case .lower: return "lower"
        case .middle: return "middle"
        case .higher: return "higher"
        }
    }
}

/// Nutrient values read from a label or a database. Missing values are nil, never guessed.
struct NutritionFacts: Equatable, Hashable {
    var basis: NutritionBasis = .unknown
    var energyKcal: Double?
    var proteinG: Double?
    var fatG: Double?
    var satFatG: Double?
    var transFatG: Double?
    var carbsG: Double?
    var sugarsG: Double?
    var sodiumMg: Double?

    /// True when at least one of the two nutrients we rate was found.
    var hasRatableValues: Bool {
        sugarsG != nil || sodiumMg != nil
    }
}

/// Where the traffic-light cut-offs come from. All numbers here are starting values.
/// A nurse or dietitian must confirm or change them before real use.
///
/// Food (per 100 g): sugars and sodium cut-offs follow the UK front-of-pack traffic-light
/// scheme (sugars low <= 5 g, high > 22.5 g; salt low <= 0.3 g, high > 1.5 g, shown here
/// as sodium: low <= 120 mg, high > 600 mg).
/// Drinks (per 100 ml): UK drinks cut-offs for sugars only (low <= 2.5 g, high > 11.25 g).
/// Carbohydrate is shown but not rated: the dietitian has not set a cut-off.
struct RatingRules {
    var sugarLowMaxPer100g = 5.0
    var sugarHighAbovePer100g = 22.5
    var sugarLowMaxPer100ml = 2.5
    var sugarHighAbovePer100ml = 11.25
    var sodiumLowMaxMgPer100g = 120.0
    var sodiumHighAboveMgPer100g = 600.0

    static let standard = RatingRules()

    func sugarLevel(_ grams: Double, basis: NutritionBasis) -> Level? {
        switch basis {
        case .per100g:
            return level(grams, lowMax: sugarLowMaxPer100g, highAbove: sugarHighAbovePer100g)
        case .per100ml:
            return level(grams, lowMax: sugarLowMaxPer100ml, highAbove: sugarHighAbovePer100ml)
        case .perServing, .unknown:
            return nil
        }
    }

    /// Sodium is rated for food only. Drinks and per-serving labels are not rated.
    func sodiumLevel(_ milligrams: Double, basis: NutritionBasis) -> Level? {
        guard basis == .per100g else { return nil }
        return level(milligrams, lowMax: sodiumLowMaxMgPer100g, highAbove: sodiumHighAboveMgPer100g)
    }

    private func level(_ value: Double, lowMax: Double, highAbove: Double) -> Level {
        if value <= lowMax { return .lower }
        if value > highAbove { return .higher }
        return .middle
    }
}

/// The traffic-light result for one scan.
struct NutritionAssessment: Equatable {
    let sugar: Level?
    let sodium: Level?

    /// The worst of the available levels, or nil when nothing could be rated.
    var overall: Level? {
        [sugar, sodium].compactMap { $0 }.max()
    }

    static func assess(_ facts: NutritionFacts, rules: RatingRules = .standard) -> NutritionAssessment {
        NutritionAssessment(
            sugar: facts.sugarsG.flatMap { rules.sugarLevel($0, basis: facts.basis) },
            sodium: facts.sodiumMg.flatMap { rules.sodiumLevel($0, basis: facts.basis) }
        )
    }
}

/// Everything the result screen needs for one scan.
struct ScanOutcome: Identifiable, Hashable {
    enum Source: String, Hashable {
        case barcode
        case label
    }

    let id = UUID()
    let source: Source
    let barcode: String?
    let productName: String?
    let facts: NutritionFacts
}
