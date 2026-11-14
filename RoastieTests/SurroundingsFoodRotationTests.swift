import XCTest
@testable import Roastie

final class SurroundingsFoodRotationTests: XCTestCase {
    private let regions: [SurroundingsRegion] = [
        .southAsia, .eastAsia, .southeastAsia, .middleEastNorthAfrica, .europe,
        .subSaharanAfrica, .northAmerica, .latinAmerica, .oceania, .general
    ]
    private let kinds: [SurroundingsSuggestion.Kind] = [.warm, .humid, .cool, .wet, .mild]

    private func calendar(_ zone: String = "GMT") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func ideas(_ kind: SurroundingsSuggestion.Kind, _ region: SurroundingsRegion,
                       _ date: Date, calendar: Calendar) -> [String] {
        SurroundingsSuggestion(kind: kind, title: "", detail: "")
            .foodPointers(in: region, on: date, calendar: calendar)
    }

    func testEveryRegionAndWeatherKindChangesActualFoodsAcrossFourDays() {
        let calendar = calendar()
        let start = date("2026-11-14T12:00:00Z")
        for region in regions {
            for kind in kinds {
                let days = (0..<4).map { offset in
                    ideas(kind, region, calendar.date(byAdding: .day, value: offset, to: start)!, calendar: calendar)
                }
                XCTAssertEqual(Set(days).count, 4, "Fixed list for \(kind) \(region)")
                // Each slot changes ingredients, not just list order or framing.
                for slot in 0..<SurroundingsSuggestion.foodSlotCount {
                    XCTAssertEqual(Set(days.map { $0[slot] }).count, 4, "Repeated slot \(slot): \(kind) \(region)")
                }
            }
        }
    }

    func testEveryRotatingSetHasThreeDistinctBoundedOptionalIdeas() {
        let calendar = calendar()
        let start = date("2026-11-14T12:00:00Z")
        for offset in 0..<4 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            for region in regions {
                for kind in kinds {
                    let suggestion = SurroundingsSuggestion(kind: kind, title: "", detail: "")
                    let pointers = suggestion.foodPointers(in: region, on: day, calendar: calendar)
                    XCTAssertEqual(pointers.count, 3)
                    XCTAssertEqual(Set(pointers).count, 3)
                    XCTAssertTrue(pointers.allSatisfy { !$0.isEmpty && $0.count < 120 })
                    if let tip = suggestion.safetyTip { XCTAssertFalse(pointers.contains(tip)) }
                }
            }
        }
    }

    func testRepeatedRendersAndRecreatedSuggestionsStayStableWithinLocalDay() {
        let calendar = calendar("Asia/Kolkata")
        let first = date("2026-11-13T18:30:00Z") // local midnight
        let last = date("2026-11-14T18:29:59Z")
        for region in regions {
            for kind in kinds {
                let expected = ideas(kind, region, first, calendar: calendar)
                for _ in 0..<10 {
                    XCTAssertEqual(ideas(kind, region, last, calendar: calendar), expected)
                }
            }
        }
    }

    func testFreshWeatherChecksDoNotReshuffleSameDayIdeas() throws {
        let first = date("2026-11-14T09:00:00Z")
        let second = date("2026-11-14T15:00:00Z")
        let weather = SurroundingsWeather(temperatureC: 20, apparentTemperatureC: 20,
                                         humidityPercent: 50, weatherCode: 0, observedAt: first)
        let updated = SurroundingsWeather(temperatureC: 21, apparentTemperatureC: 21,
                                         humidityPercent: 55, weatherCode: 1, observedAt: second)
        let initial = try XCTUnwrap(SurroundingsSuggestion.make(weather: weather, now: first))
        let refreshed = try XCTUnwrap(SurroundingsSuggestion.make(weather: updated, now: second))
        for region in regions {
            XCTAssertEqual(initial.foodPointers(in: region, on: first, calendar: calendar()),
                           refreshed.foodPointers(in: region, on: second, calendar: calendar()))
        }
    }

    func testRotationUsesLocalMidnightRatherThanUTCMidnight() {
        let calendar = calendar("Asia/Kolkata")
        let before = date("2026-11-14T18:29:59Z")
        let after = date("2026-11-14T18:30:00Z")
        XCTAssertNotEqual(ideas(.mild, .southAsia, before, calendar: calendar),
                          ideas(.mild, .southAsia, after, calendar: calendar))
        XCTAssertEqual(ideas(.mild, .southAsia, after, calendar: calendar),
                       ideas(.mild, .southAsia, date("2026-11-15T00:00:00Z"), calendar: calendar))
    }

    func testDaylightSavingDaysRemainStableAndRotateAtNextMidnight() {
        let calendar = calendar("America/New_York")
        for (first, last, next) in [
            ("2026-03-08T05:00:00Z", "2026-03-09T03:59:59Z", "2026-03-09T04:00:00Z"),
            ("2026-11-01T04:00:00Z", "2026-11-02T04:59:59Z", "2026-11-02T05:00:00Z")
        ] {
            for region in regions {
                let initial = ideas(.cool, region, date(first), calendar: calendar)
                XCTAssertEqual(initial, ideas(.cool, region, date(last), calendar: calendar))
                XCTAssertNotEqual(initial, ideas(.cool, region, date(next), calendar: calendar))
            }
        }
    }

    func testYearAndLeapDayBoundariesAdvanceTheRotation() {
        let calendar = calendar()
        for (before, after) in [
            ("2026-12-31T23:59:59Z", "2027-01-01T00:00:00Z"),
            ("2028-02-28T23:59:59Z", "2028-02-29T00:00:00Z"),
            ("2028-02-29T23:59:59Z", "2028-03-01T00:00:00Z")
        ] {
            XCTAssertNotEqual(ideas(.wet, .general, date(before), calendar: calendar),
                              ideas(.wet, .general, date(after), calendar: calendar))
        }
    }

    func testWeatherStillSelectsSuitableFoodTypeOnEveryRotationDay() {
        let calendar = calendar()
        let start = date("2026-11-14T12:00:00Z")
        for offset in 0..<4 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            for region in regions {
                XCTAssertTrue(ideas(.warm, region, day, calendar: calendar)[2].contains("cool snack"))
                XCTAssertTrue(ideas(.cool, region, day, calendar: calendar)[1].contains("warm meal"))
                XCTAssertTrue(ideas(.wet, region, day, calendar: calendar)[0].contains("at home"))
                XCTAssertNotEqual(ideas(.cool, region, day, calendar: calendar), ideas(.warm, region, day, calendar: calendar))
            }
        }
    }

    func testDisplayCalendarIdentifierDoesNotChangeFoodsForTheSameLocalDay() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar().timeZone
        let now = date("2026-11-14T12:00:00Z")
        XCTAssertEqual(ideas(.mild, .general, now, calendar: buddhist),
                       ideas(.mild, .general, now, calendar: calendar()))
    }
}
