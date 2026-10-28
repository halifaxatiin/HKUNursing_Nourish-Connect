import XCTest
@testable import NourishConnect

final class ThemeTests: XCTestCase {
    func testScaleIsClampedToRange() {
        XCTAssertEqual(Theme(scale: 0.2).scale, 1.0)
        XCTAssertEqual(Theme(scale: 5.0).scale, 2.0)
        XCTAssertEqual(Theme(scale: 1.5).scale, 1.5)
    }

    func testMissingSettingsUseDefaults() {
        let theme = Theme(settings: nil)
        XCTAssertEqual(theme, Theme())
        XCTAssertTrue(theme.speechEnabled)
        XCTAssertFalse(theme.highContrast)
    }

    func testSettingsAreCopiedIntoTheme() {
        let settings = UserSettings(textScale: 1.8, highContrast: true, speechEnabled: false, speechRate: 0.35)
        let theme = Theme(settings: settings)
        XCTAssertEqual(theme.scale, 1.8)
        XCTAssertTrue(theme.highContrast)
        XCTAssertFalse(theme.speechEnabled)
        XCTAssertEqual(theme.speechRate, 0.35)
    }

    func testCallConfirmationNamesTheContact() {
        XCTAssertTrue(Str.callConfirmTitle("陳姑娘").contains("陳姑娘"))
    }
}
