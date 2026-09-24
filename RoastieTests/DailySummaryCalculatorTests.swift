import XCTest
@testable import Roastie

final class DailySummaryCalculatorTests: XCTestCase {
    func testCompleteDayUsesDocumentedWeights() {
        let result = DailySummaryCalculator.calculate(input(
            sleep: 7,
            water: 3,
            goal: 4,
            food: 80,
            steps: 4_000
        ))

        XCTAssertEqual(result.score, 83)
        XCTAssertTrue(result.isComplete)
    }

    func testMissingStepsDoNotPenalizeTheScore() {
        let withoutSteps = DailySummaryCalculator.calculate(input(
            sleep: 7,
            water: 4,
            goal: 4,
            food: 80,
            steps: nil
        ))
        let withFullSteps = DailySummaryCalculator.calculate(input(
            sleep: 7,
            water: 4,
            goal: 4,
            food: 80,
            steps: 8_000
        ))

        XCTAssertEqual(withoutSteps.score, withFullSteps.score)
    }

    func testStepsCanMoveScoreByAtMostFivePoints() {
        let noSteps = DailySummaryCalculator.calculate(input(
            sleep: 7,
            water: 4,
            goal: 4,
            food: 100,
            steps: 0
        ))
        let fullSteps = DailySummaryCalculator.calculate(input(
            sleep: 7,
            water: 4,
            goal: 4,
            food: 100,
            steps: 8_000
        ))

        XCTAssertEqual(fullSteps.score - noSteps.score, 5)
    }

    func testMissingCoreMetricMakesReportIncomplete() {
        let result = DailySummaryCalculator.calculate(input(
            sleep: nil,
            water: 4,
            goal: 4,
            food: nil,
            steps: 8_000
        ))

        XCTAssertFalse(result.isComplete)
        XCTAssertTrue(result.detail.contains("Sleep —"))
        XCTAssertTrue(result.detail.contains("Food —"))
    }

    func testSleepRangeBoundariesReceiveFullCredit() {
        let lower = DailySummaryCalculator.calculate(input(sleep: 6, water: 0, goal: 4, food: nil, steps: nil))
        let upper = DailySummaryCalculator.calculate(input(sleep: 9, water: 0, goal: 4, food: nil, steps: nil))

        XCTAssertEqual(lower.score, upper.score)
    }

    private func input(
        sleep: Double?,
        water: Int,
        goal: Int,
        food: Int?,
        steps: Int?
    ) -> DailySummaryInput {
        DailySummaryInput(
            sleepHours: sleep,
            waterBottlesLogged: water,
            waterGoalBottles: goal,
            foodScore: food,
            steps: steps
        )
    }
}
