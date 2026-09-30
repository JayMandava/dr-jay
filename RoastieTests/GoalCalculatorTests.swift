import XCTest
@testable import Roastie

final class GoalCalculatorTests: XCTestCase {
    func testSleepStatusBoundaries() {
        XCTAssertEqual(GoalCalculator.sleepStatus(hours: nil), .noData)
        XCTAssertEqual(GoalCalculator.sleepStatus(hours: 5.9), .under)
        XCTAssertEqual(GoalCalculator.sleepStatus(hours: 6), .inRange)
        XCTAssertEqual(GoalCalculator.sleepStatus(hours: 9), .inRange)
        XCTAssertEqual(GoalCalculator.sleepStatus(hours: 9.1), .over)
    }

    func testSleepDetailUsesCompactCapitalizedCopy() {
        XCTAssertEqual(GoalCalculator.sleepDetail(hours: nil), "No sleep data yet")
        XCTAssertEqual(GoalCalculator.sleepDetail(hours: 6), "Slept 6h")
        XCTAssertEqual(GoalCalculator.sleepDetail(hours: 7.5), "Slept 7.5h")
    }

    func testWaterRequiresEntireGoal() {
        XCTAssertFalse(GoalCalculator.waterMet(bottlesLogged: 3, goal: 4))
        XCTAssertTrue(GoalCalculator.waterMet(bottlesLogged: 4, goal: 4))
        XCTAssertTrue(GoalCalculator.waterMet(bottlesLogged: 5, goal: 4))
    }
}
