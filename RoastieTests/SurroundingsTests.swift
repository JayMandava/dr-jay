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

    func testEveryWeatherBranchOffersFourDistinctFoodChoices() throws {
        for sample in [weather(30), weather(24, humidity: 75), weather(10), weather(code: 61), weather()] {
            let suggestion = try XCTUnwrap(SurroundingsSuggestion.make(weather: sample, now: now))
            XCTAssertEqual(suggestion.foodPointers.count, 4)
            XCTAssertEqual(Set(suggestion.foodPointers).count, 4)
            XCTAssertTrue(suggestion.foodPointers.allSatisfy { !$0.isEmpty && $0.count < 100 })
        }
        XCTAssertTrue(try XCTUnwrap(SurroundingsSuggestion.make(weather: weather(30), now: now)).foodPointers[0].contains("cucumber"))
        XCTAssertTrue(try XCTUnwrap(SurroundingsSuggestion.make(weather: weather(10), now: now)).foodPointers[0].contains("warm"))
    }

    func testHydrationUsesExistingGoalAndBottleSize() {
        let hydration = SurroundingsHydration(goalBottles: 4, bottlesLogged: 2, bottleSizeMl: 750)
        XCTAssertEqual(hydration.remainingBottles, 2)
        XCTAssertEqual(hydration.title, "2 bottles left today (1500 ml)")
        XCTAssertTrue(hydration.detail.contains("2 of 4 bottles logged · 750 ml each"))
        XCTAssertEqual(SurroundingsHydration(goalBottles: 6, bottlesLogged: 5, bottleSizeMl: 250).title,
                       "1 bottle left today (250 ml)")
        XCTAssertEqual(SurroundingsHydration(goalBottles: 4, bottlesLogged: 0, bottleSizeMl: 500).remainingBottles, 4)
    }

    func testHydrationUpdatesAfterLogOrUndoWithoutChangingGoal() {
        for logged in 0...4 {
            let hydration = SurroundingsHydration(goalBottles: 4, bottlesLogged: logged, bottleSizeMl: 750)
            XCTAssertEqual(hydration.remainingBottles, 4 - logged)
            XCTAssertEqual(hydration.goalBottles, 4)
        }
        let afterUndo = SurroundingsHydration(goalBottles: 4, bottlesLogged: 3, bottleSizeMl: 750)
        XCTAssertEqual(afterUndo.remainingBottles, 1)
    }

    func testMetOrExceededGoalNeverAsksForExtraBottles() {
        for logged in [4, 5, Int.max] {
            let hydration = SurroundingsHydration(goalBottles: 4, bottlesLogged: logged, bottleSizeMl: 750)
            XCTAssertEqual(hydration.remainingBottles, 0)
            XCTAssertEqual(hydration.title, "Your water goal is met today")
            XCTAssertFalse(hydration.detail.contains("remainder"))
        }
    }

    func testHydrationHandlesInvalidImportedValuesWithoutOverflow() {
        for goal in [0, -1, Int.min] {
            let hydration = SurroundingsHydration(goalBottles: goal, bottlesLogged: 0, bottleSizeMl: 750)
            XCTAssertEqual(hydration.remainingBottles, 0)
            XCTAssertEqual(hydration.title, "Check your water goal in Settings")
        }
        XCTAssertEqual(SurroundingsHydration(goalBottles: 4, bottlesLogged: -1, bottleSizeMl: 750).remainingBottles, 4)
        for size in [0, -1, Int.min, Int.max] {
            let hydration = SurroundingsHydration(goalBottles: 4, bottlesLogged: 0, bottleSizeMl: size)
            XCTAssertEqual(hydration.title, "4 bottles left today")
        }
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
