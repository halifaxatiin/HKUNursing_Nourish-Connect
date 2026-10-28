import XCTest
@testable import NourishConnect

final class DishCatalogTests: XCTestCase {
    func testIdsAreUniqueAndNamed() {
        let ids = DishCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(DishCatalog.all.allSatisfy { !$0.name.isEmpty })
        XCTAssertGreaterThanOrEqual(DishCatalog.all.count, 20)
    }

    func testEveryDishCanBeRatedForSugar() {
        for dish in DishCatalog.all {
            XCTAssertNotNil(NutritionAssessment.assess(dish.facts).sugar, dish.id)
        }
    }

    func testDrinksAreNotRatedForSodium() {
        for dish in DishCatalog.all where dish.isDrink {
            XCTAssertNil(NutritionAssessment.assess(dish.facts).sodium, dish.id)
        }
    }

    func testKnownRatings() {
        XCTAssertEqual(NutritionAssessment.assess(DishCatalog.dish(id: "steamed_rice")!.facts).overall, .lower)
        XCTAssertEqual(NutritionAssessment.assess(DishCatalog.dish(id: "pineapple_bun_butter")!.facts).sugar, .middle)
        XCTAssertEqual(NutritionAssessment.assess(DishCatalog.dish(id: "char_siu_rice")!.facts).sodium, .middle)
    }

    func testLookup() {
        XCTAssertEqual(DishCatalog.dish(id: "egg_tart")?.name, "蛋撻")
        XCTAssertNil(DishCatalog.dish(id: "nope"))
    }
}

final class DishDecisionTests: XCTestCase {
    func testConfidentGuessIsStillAQuestion() {
        let result = DishDecision.decide([RawGuess(id: "egg_tart", confidence: 0.95)])
        XCTAssertEqual(result, .confirm(DishCatalog.dish(id: "egg_tart")!))
    }

    func testUnsureOffersUpToThree() {
        let result = DishDecision.decide([
            RawGuess(id: "har_gow", confidence: 0.4),
            RawGuess(id: "siu_mai", confidence: 0.3),
            RawGuess(id: "rice_roll", confidence: 0.2),
            RawGuess(id: "egg_tart", confidence: 0.15)
        ])
        guard case .choose(let dishes) = result else { return XCTFail("expected choose") }
        XCTAssertEqual(dishes.map(\.id), ["har_gow", "siu_mai", "rice_roll"])
    }

    func testNoUsefulGuessShowsList() {
        XCTAssertEqual(DishDecision.decide([]), .list)
        XCTAssertEqual(DishDecision.decide([RawGuess(id: "egg_tart", confidence: 0.05)]), .list)
    }

    func testUnknownLabelsAreIgnored() {
        XCTAssertEqual(DishDecision.decide([RawGuess(id: "pizza", confidence: 0.99)]), .list)
    }

    func testNoModelMeansNotAvailable() {
        // The model ships separately; without it the app falls back to the list.
        if Bundle.main.url(forResource: CoreMLDishClassifier.modelName, withExtension: "mlmodelc") == nil {
            XCTAssertFalse(CoreMLDishClassifier().isAvailable)
        }
    }
}
