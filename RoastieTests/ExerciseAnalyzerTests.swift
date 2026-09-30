import XCTest
@testable import Roastie

final class ExerciseAnalyzerTests: XCTestCase {
    func testExplicitMinutesAndCategoryAreExtracted() throws {
        let entry = try XCTUnwrap(ExerciseAnalyzer.entry(from: "30-minute run"))
        XCTAssertEqual(entry.durationMinutes, 30)
        XCTAssertEqual(entry.category, .cardio)
    }

    func testHoursAndMinutesAreCombined() throws {
        let entry = try XCTUnwrap(ExerciseAnalyzer.entry(from: "Gym for 1h 15m"))
        XCTAssertEqual(entry.durationMinutes, 75)
        XCTAssertEqual(entry.category, .strength)
    }

    func testMissingDurationIsLoggedButUnscored() throws {
        let entry = try XCTUnwrap(ExerciseAnalyzer.entry(from: "Played badminton"))
        XCTAssertNil(entry.durationMinutes)
        XCTAssertEqual(entry.category, .sport)
        XCTAssertNil(ExerciseAnalyzer.score(minutes: nil))
    }

    func testExerciseScoreCapsAtThirtyMinutes() {
        XCTAssertEqual(ExerciseAnalyzer.score(minutes: 15), 50)
        XCTAssertEqual(ExerciseAnalyzer.score(minutes: 30), 100)
        XCTAssertEqual(ExerciseAnalyzer.score(minutes: 90), 100)
    }
}
