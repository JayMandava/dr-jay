import XCTest
@testable import Roastie

final class AppSettingsTests: XCTestCase {
    func testNewSettingsUseGentleFoodSafeDefaults() {
        let settings = AppSettings()

        XCTAssertEqual(settings.roastIntensity, .gentle)
        XCTAssertFalse(settings.foodRoastsEnabled)
        XCTAssertEqual(settings.dailyScoreProfile, .balanced)
    }

    func testLegacySettingsDecodeWithoutNewKeys() throws {
        let data = Data(
            """
            {
              "waterGoalBottles": 5,
              "bottleSizeMl": 500,
              "roastIntensity": "spicy",
              "healthKitEnabled": true,
              "onboardingComplete": true
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.waterGoalBottles, 5)
        XCTAssertEqual(settings.roastIntensity, .spicy)
        XCTAssertFalse(settings.foodRoastsEnabled)
        XCTAssertEqual(settings.dailyScoreProfile, .balanced)
    }
}
