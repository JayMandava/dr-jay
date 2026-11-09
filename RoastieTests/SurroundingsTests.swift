import XCTest
@testable import Roastie

final class SurroundingsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func weather(_ temperature: Double = 20, feelsLike: Double = 20,
                         humidity: Double = 50, code: Int = 0, age: Double = 0) -> SurroundingsWeather {
        SurroundingsWeather(temperatureC: temperature, apparentTemperatureC: feelsLike,
                            humidityPercent: humidity, weatherCode: code,
                            observedAt: now.addingTimeInterval(-age))
    }

    func testGentleWeatherBranches() {
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(30), now: now)?.kind, .warm)
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(25, feelsLike: 28), now: now)?.kind, .warm)
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(24, humidity: 75), now: now)?.kind, .humid)
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(10), now: now)?.kind, .cool)
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(code: 61), now: now)?.kind, .wet)
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(), now: now)?.kind, .mild)
    }

    func testThresholdsDoNotOverstateConditions() {
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(29, feelsLike: 27.9), now: now)?.kind, .mild)
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(23.9, humidity: 100), now: now)?.kind, .mild)
        XCTAssertEqual(SurroundingsSuggestion.make(weather: weather(10.1), now: now)?.kind, .mild)
    }

    func testRejectsExpiredFutureAndInvalidWeather() {
        for sample in [weather(age: 1800), weather(age: -1), weather(.nan),
                       weather(feelsLike: .infinity), weather(humidity: -1), weather(humidity: 101)] {
            XCTAssertNil(SurroundingsSuggestion.make(weather: sample, now: now))
        }
    }

    func testPreviousDayWeatherCannotEarnANewDayBonus() {
        let midnight = Calendar.current.startOfDay(for: now)
        let previous = SurroundingsWeather(temperatureC: 20, apparentTemperatureC: 20,
                                          humidityPercent: 50, weatherCode: 0,
                                          observedAt: midnight.addingTimeInterval(-60))
        XCTAssertNil(SurroundingsSuggestion.make(weather: previous, now: midnight.addingTimeInterval(60)))
    }

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
