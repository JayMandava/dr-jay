import XCTest
@testable import Roastie

final class SurroundingsSettingsTests: XCTestCase {
    func testOptInDefaultsAndSettingsRoundTrip() throws {
        XCTAssertFalse(AppSettings().surroundingsAwarenessEnabled)
        XCTAssertFalse(try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8)).surroundingsAwarenessEnabled)
        let original = AppSettings(surroundingsAwarenessEnabled: true)
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(original))
        XCTAssertTrue(restored.surroundingsAwarenessEnabled)
        XCTAssertEqual(restored.waterGoalBottles, original.waterGoalBottles)
        XCTAssertEqual(restored.dailyScoreProfile, original.dailyScoreProfile)
    }
}
