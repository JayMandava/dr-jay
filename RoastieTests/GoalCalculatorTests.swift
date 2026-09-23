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

    func testWaterRequiresEntireGoal() {
        XCTAssertFalse(GoalCalculator.waterMet(bottlesLogged: 3, goal: 4))
        XCTAssertTrue(GoalCalculator.waterMet(bottlesLogged: 4, goal: 4))
        XCTAssertTrue(GoalCalculator.waterMet(bottlesLogged: 5, goal: 4))
    }
}
