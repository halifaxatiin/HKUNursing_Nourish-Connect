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

    func testEveryDishAppearsOnceInTheSections() {
        let listed = DishCatalog.sections.flatMap { $0.dishes.map(\.id) }
        XCTAssertEqual(listed.count, DishCatalog.all.count)
        XCTAssertEqual(Set(listed), Set(DishCatalog.all.map(\.id)))
    }

    func testSectionsFollowCategoryOrderAndAreNeverEmpty() {
        let order = DishCatalog.sections.map(\.category)
        XCTAssertEqual(order, DishCategory.allCases.filter { order.contains($0) })
        XCTAssertTrue(DishCatalog.sections.allSatisfy { !$0.dishes.isEmpty })
        XCTAssertTrue(DishCategory.allCases.allSatisfy { !$0.title.isEmpty })
    }

    func testCategoriesOfKnownDishes() {
        XCTAssertEqual(DishCatalog.dish(id: "wonton_noodles")?.category, .noodles)
        XCTAssertEqual(DishCatalog.dish(id: "har_gow")?.category, .dimSum)
        XCTAssertEqual(DishCatalog.dish(id: "hk_milk_tea")?.category, .drinks)
        XCTAssertEqual(DishCatalog.dishes(in: .rice).first?.id, "steamed_rice")
    }

    func testLookup() {
        XCTAssertEqual(DishCatalog.dish(id: "egg_tart")?.name, "蛋撻")
        XCTAssertNil(DishCatalog.dish(id: "nope"))
    }
}
