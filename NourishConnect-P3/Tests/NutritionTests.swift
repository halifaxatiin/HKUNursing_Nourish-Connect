import XCTest
@testable import NourishConnect

final class NutritionTests: XCTestCase {
    private let rules = RatingRules.standard

    func testSugarCutoffsPer100g() {
        XCTAssertEqual(rules.sugarLevel(5.0, basis: .per100g), .lower)
        XCTAssertEqual(rules.sugarLevel(5.1, basis: .per100g), .middle)
        XCTAssertEqual(rules.sugarLevel(22.5, basis: .per100g), .middle)
        XCTAssertEqual(rules.sugarLevel(22.6, basis: .per100g), .higher)
    }

    func testSugarCutoffsPer100ml() {
        XCTAssertEqual(rules.sugarLevel(2.5, basis: .per100ml), .lower)
        XCTAssertEqual(rules.sugarLevel(11.25, basis: .per100ml), .middle)
        XCTAssertEqual(rules.sugarLevel(11.3, basis: .per100ml), .higher)
    }

    func testSodiumCutoffsPer100g() {
        XCTAssertEqual(rules.sodiumLevel(120, basis: .per100g), .lower)
        XCTAssertEqual(rules.sodiumLevel(121, basis: .per100g), .middle)
        XCTAssertEqual(rules.sodiumLevel(600, basis: .per100g), .middle)
        XCTAssertEqual(rules.sodiumLevel(601, basis: .per100g), .higher)
    }

    func testSodiumIsNotRatedForDrinksOrServings() {
        XCTAssertNil(rules.sodiumLevel(500, basis: .per100ml))
        XCTAssertNil(rules.sodiumLevel(500, basis: .perServing))
        XCTAssertNil(rules.sugarLevel(10, basis: .perServing))
        XCTAssertNil(rules.sugarLevel(10, basis: .unknown))
    }

    func testOverallIsTheWorstLevel() {
        var facts = NutritionFacts()
        facts.basis = .per100g
        facts.sugarsG = 3      // lower
        facts.sodiumMg = 700   // higher
        let a = NutritionAssessment.assess(facts)
        XCTAssertEqual(a.sugar, .lower)
        XCTAssertEqual(a.sodium, .higher)
        XCTAssertEqual(a.overall, .higher)
    }

    func testOverallIsNilWhenNothingCanBeRated() {
        XCTAssertNil(NutritionAssessment.assess(NutritionFacts()).overall)
    }

    // MARK: Open Food Facts

    func testOpenFoodFactsFoundProduct() {
        let json = """
        {"status":1,"product":{"product_name":"Test Soy Milk",
         "nutriments":{"sugars_100g":3.2,"sodium_100g":0.05,
                       "carbohydrates_100g":"5.1","energy-kcal_100g":40}}}
        """
        guard case let .found(name, facts) = OpenFoodFactsParser.parse(Data(json.utf8)) else {
            return XCTFail("expected a found product")
        }
        XCTAssertEqual(name, "Test Soy Milk")
        XCTAssertEqual(facts.basis, .per100g)
        XCTAssertEqual(facts.sugarsG, 3.2)
        XCTAssertEqual(facts.sodiumMg ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(facts.carbsG, 5.1)
        XCTAssertEqual(facts.energyKcal, 40)
    }

    func testOpenFoodFactsPrefersChineseName() {
        let json = """
        {"status":1,"product":{"product_name":"Soy","product_name_zh":"豆漿",
         "nutriments":{"sugars_100g":3}}}
        """
        guard case let .found(name, _) = OpenFoodFactsParser.parse(Data(json.utf8)) else {
            return XCTFail("expected a found product")
        }
        XCTAssertEqual(name, "豆漿")
    }

    func testOpenFoodFactsSaltFallback() {
        let json = #"{"status":1,"product":{"nutriments":{"salt_100g":1.5}}}"#
        guard case let .found(_, facts) = OpenFoodFactsParser.parse(Data(json.utf8)) else {
            return XCTFail("expected a found product")
        }
        XCTAssertEqual(facts.sodiumMg ?? 0, 600, accuracy: 0.001)
    }

    func testOpenFoodFactsNotFound() {
        let json = #"{"status":0,"status_verbose":"product not found"}"#
        XCTAssertEqual(OpenFoodFactsParser.parse(Data(json.utf8)), .notFound)
    }

    func testOpenFoodFactsWithoutSugarOrSodiumIsNotFound() {
        let json = #"{"status":1,"product":{"nutriments":{"proteins_100g":4}}}"#
        XCTAssertEqual(OpenFoodFactsParser.parse(Data(json.utf8)), .notFound)
    }

    func testOpenFoodFactsBrokenJsonIsNotFound() {
        XCTAssertEqual(OpenFoodFactsParser.parse(Data("not json".utf8)), .notFound)
    }

    // MARK: Narration

    func testNumberFormatting() {
        XCTAssertEqual(Narration.number(12), "12")
        XCTAssertEqual(Narration.number(12.46), "12.5")
        XCTAssertEqual(Narration.number(0.04), "0")
    }

    func testNarrationForHighSugarMentionsValueAndLevel() {
        var facts = NutritionFacts()
        facts.basis = .per100g
        facts.sugarsG = 12.5
        facts.sodiumMg = 700
        let outcome = ScanOutcome(source: .label, barcode: nil, productName: nil, facts: facts)
        let text = Narration.spoken(outcome: outcome, assessment: NutritionAssessment.assess(facts))
        XCTAssertTrue(text.contains("12.5"))
        XCTAssertTrue(text.contains("700"))
        XCTAssertTrue(text.contains(Str.levelHigh))
        XCTAssertTrue(text.contains(Str.checkPackage))
    }

    func testNarrationForPerServingLabelDoesNotRate() {
        var facts = NutritionFacts()
        facts.basis = .perServing
        facts.sugarsG = 6
        let outcome = ScanOutcome(source: .label, barcode: nil, productName: nil, facts: facts)
        let text = Narration.spoken(outcome: outcome, assessment: NutritionAssessment.assess(facts))
        XCTAssertEqual(text, Str.perServingNote)
    }
}
