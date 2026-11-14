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

    private let allRegions: [SurroundingsRegion] = [
        .southAsia, .eastAsia, .southeastAsia, .middleEastNorthAfrica, .europe,
        .subSaharanAfrica, .northAmerica, .latinAmerica, .oceania, .general
    ]

    func testEveryWeatherBranchInEveryRegionOffersThreeDistinctFoodChoices() throws {
        for sample in [weather(30), weather(24, humidity: 75), weather(10), weather(code: 61), weather()] {
            let suggestion = try XCTUnwrap(SurroundingsSuggestion.make(weather: sample, now: now))
            for region in allRegions {
                let pointers = suggestion.foodPointers(in: region, on: now)
                XCTAssertEqual(pointers.count, 3, "\(suggestion.kind) \(region)")
                XCTAssertEqual(Set(pointers).count, 3, "\(suggestion.kind) \(region)")
                XCTAssertTrue(pointers.allSatisfy { !$0.isEmpty && $0.count < 120 }, "\(suggestion.kind) \(region)")
            }
        }
    }

    func testSafetyTipsAreRemindersNotPickableIdeas() throws {
        for (sample, expectsTip) in [(weather(30), true), (weather(24, humidity: 75), true), (weather(code: 61), true),
                                     (weather(10), false), (weather(), false)] {
            let suggestion = try XCTUnwrap(SurroundingsSuggestion.make(weather: sample, now: now))
            XCTAssertEqual(suggestion.safetyTip != nil, expectsTip, "\(suggestion.kind)")
            XCTAssertEqual(suggestion.foodPointers(in: .general, on: now).count, SurroundingsSuggestion.foodSlotCount)
            if let tip = suggestion.safetyTip {
                XCTAssertFalse(suggestion.foodPointers(in: .general, on: now).contains(tip))
            }
        }
    }

    func testFoodIdeasFollowTheRegionRatherThanOneCuisine() throws {
        let mild = try XCTUnwrap(SurroundingsSuggestion.make(weather: weather(), now: now))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let originalDay = Date(timeIntervalSince1970: 12 * 60 * 60) // rotation day zero
        let south = mild.foodPointers(in: .southAsia, on: originalDay, calendar: calendar).joined(separator: " ")
        let east = mild.foodPointers(in: .eastAsia, on: originalDay, calendar: calendar).joined(separator: " ")
        let europe = mild.foodPointers(in: .europe, on: originalDay, calendar: calendar).joined(separator: " ")
        XCTAssertTrue(south.contains("dal"))
        XCTAssertTrue(east.contains("tofu"))
        XCTAssertTrue(europe.contains("potatoes"))
        XCTAssertFalse(europe.contains("dal"))
        XCTAssertFalse(east.contains("roti"))
        XCTAssertEqual(Set(allRegions.map { mild.foodPointers(in: $0, on: now) }).count, allRegions.count)
    }

    func testRegionComesFromRoundedCoordinates() {
        let cases: [(Double, Double, SurroundingsRegion)] = [
            (19.1, 72.9, .southAsia), (35.7, 139.7, .eastAsia), (13.8, 100.5, .southeastAsia),
            (30.0, 31.2, .middleEastNorthAfrica), (48.9, 2.4, .europe), (-1.3, 36.8, .subSaharanAfrica),
            (40.7, -74.0, .northAmerica), (-23.5, -46.6, .latinAmerica), (-33.9, 151.2, .oceania),
            (-41.3, 174.8, .oceania), (0.0, -30.0, .general)
        ]
        for (lat, lon, expected) in cases {
            XCTAssertEqual(SurroundingsRegion(latitude: lat, longitude: lon), expected, "\(lat),\(lon)")
        }
        XCTAssertEqual(SurroundingsRegion(latitude: .nan, longitude: 10), .general)
    }

    func testWeatherRegionDefaultsToGeneralAndDoesNotChangeTheSuggestionKind() throws {
        XCTAssertEqual(weather().region, .general)
        var tokyo = weather(30)
        tokyo.region = .eastAsia
        XCTAssertEqual(SurroundingsSuggestion.make(weather: tokyo, now: now)?.kind,
                       SurroundingsSuggestion.make(weather: weather(30), now: now)?.kind)
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

}
