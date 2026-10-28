import XCTest
@testable import NourishConnect

final class LabelParserTests: XCTestCase {
    private let singleColumn = """
    營養標籤 Nutrition Information
    每100克 Per 100g
    能量 Energy 250 千卡 kcal
    蛋白質 Protein 5.0 克 g
    總脂肪 Total fat 10.0 克 g
    飽和脂肪 Saturated fat 3.0 克 g
    反式脂肪 Trans fat 0 克 g
    碳水化合物 Carbohydrates 30.0 克 g
    糖 Sugars 12.5 克 g
    鈉 Sodium 450 毫克 mg
    """

    func testSingleColumnPer100g() {
        let f = LabelParser.parse(singleColumn)
        XCTAssertEqual(f.basis, .per100g)
        XCTAssertEqual(f.energyKcal, 250)
        XCTAssertEqual(f.proteinG, 5.0)
        XCTAssertEqual(f.fatG, 10.0)
        XCTAssertEqual(f.satFatG, 3.0)
        XCTAssertEqual(f.transFatG, 0)
        XCTAssertEqual(f.carbsG, 30.0)
        XCTAssertEqual(f.sugarsG, 12.5)
        XCTAssertEqual(f.sodiumMg, 450)
    }

    func testServingFirstThenPer100TakesSecondNumber() {
        let text = """
        Nutrition Information 營養資料
        每份 Per serving   每100克 Per 100g
        糖 Sugars 3.0 g 10.0 g
        鈉 Sodium 90 mg 300 mg
        """
        let f = LabelParser.parse(text)
        XCTAssertEqual(f.basis, .per100g)
        XCTAssertEqual(f.sugarsG, 10.0)
        XCTAssertEqual(f.sodiumMg, 300)
    }

    func testPer100FirstThenServingTakesFirstNumber() {
        let text = """
        每100克 Per 100g   每份 Per serving
        糖 Sugars 10.0 g 3.0 g
        鈉 Sodium 300 mg 90 mg
        """
        let f = LabelParser.parse(text)
        XCTAssertEqual(f.sugarsG, 10.0)
        XCTAssertEqual(f.sodiumMg, 300)
    }

    func testTwoColumnLabelWithOnlyOneNumberIsSkipped() {
        let text = """
        每份 Per serving   每100克 Per 100g
        糖 Sugars 3.0 g
        """
        XCTAssertNil(LabelParser.parse(text).sugarsG)
    }

    func testPercentColumnIsIgnored() {
        let text = """
        每100克 Per 100g
        鈉 Sodium 300 mg 15%
        """
        XCTAssertEqual(LabelParser.parse(text).sodiumMg, 300)
    }

    func testPerServingOnlyLabelIsMarkedPerServing() {
        let text = """
        每份 Per serving
        糖 Sugars 6 g
        鈉 Sodium 120 mg
        """
        let f = LabelParser.parse(text)
        XCTAssertEqual(f.basis, .perServing)
        XCTAssertEqual(f.sugarsG, 6)
        XCTAssertNil(NutritionAssessment.assess(f).overall)
    }

    func testNoBasisIsUnknownAndNotRated() {
        let f = LabelParser.parse("糖 Sugars 6 g\n鈉 Sodium 120 mg")
        XCTAssertEqual(f.basis, .unknown)
        XCTAssertNil(NutritionAssessment.assess(f).overall)
    }

    func testDrinkLabelIsPer100ml() {
        let f = LabelParser.parse("每100毫升 Per 100ml\n糖 Sugars 10 g")
        XCTAssertEqual(f.basis, .per100ml)
        XCTAssertEqual(f.sugarsG, 10)
    }

    func testEnergyFromKilojoulesIsConverted() {
        let f = LabelParser.parse("每100克 Per 100g\n能量 Energy 1046 kJ")
        XCTAssertEqual(f.energyKcal ?? 0, 250, accuracy: 0.1)
    }

    func testSaltIsConvertedToSodium() {
        let f = LabelParser.parse("每100克 Per 100g\n鹽 Salt 1.5 g")
        XCTAssertEqual(f.sodiumMg ?? 0, 600, accuracy: 0.001)
    }

    func testSodiumWrittenInGramsIsConvertedToMilligrams() {
        let f = LabelParser.parse("每100克 Per 100g\n鈉 Sodium 0.45 g")
        XCTAssertEqual(f.sodiumMg ?? 0, 450, accuracy: 0.001)
    }

    func testSodiumInMilligramsIsNotScaledAgain() {
        let f = LabelParser.parse("每100克 Per 100g\n鈉 Sodium 450 mg")
        XCTAssertEqual(f.sodiumMg, 450)
    }

    func testGarbageGivesNothingRatable() {
        let f = LabelParser.parse("Best before 12/2027\nKeep in a cool dry place")
        XCTAssertFalse(f.hasRatableValues)
    }

    func testLayoutJoinsPiecesOnTheSameRow() {
        // Vision boxes: origin bottom-left, normalised.
        let items: [(text: String, box: CGRect)] = [
            ("12.5 g", CGRect(x: 0.6, y: 0.50, width: 0.2, height: 0.04)),
            ("Sugars", CGRect(x: 0.1, y: 0.51, width: 0.3, height: 0.04)),
            ("Sodium", CGRect(x: 0.1, y: 0.40, width: 0.3, height: 0.04)),
            ("450 mg", CGRect(x: 0.6, y: 0.40, width: 0.2, height: 0.04))
        ]
        XCTAssertEqual(LabelReader.layout(items), "Sugars 12.5 g\nSodium 450 mg")
    }
}
