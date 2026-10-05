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

        XCTAssertEqual(result.score, 82)
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(result.profile, .balanced)
    }

    func testMissingStepsAreExcludedAndRemainingWeightsRebalance() {
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

        XCTAssertEqual(withoutSteps.score, 93)
        XCTAssertEqual(withFullSteps.score, 94)
        let movement = withoutSteps.weightBreakdown.first { $0.metric == .movement }
        XCTAssertNil(movement?.effectiveWeight)
        let food = withoutSteps.weightBreakdown.first { $0.metric == .food }
        XCTAssertEqual(food?.effectiveWeight ?? 0, 1.0 / 3.0, accuracy: 0.001)
    }

    func testBalancedMovementCanMoveScoreByAtMostTenPoints() {
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

        XCTAssertEqual(fullSteps.score - noSteps.score, 10)
    }

    func testExerciseCanSupplyMovementWithoutSteps() {
        let result = DailySummaryCalculator.calculate(input(
            sleep: 7,
            water: 4,
            goal: 4,
            food: 100,
            steps: nil,
            exerciseMinutes: 30,
            exerciseEntries: 1
        ))

        XCTAssertEqual(result.score, 100)
        XCTAssertTrue(result.detail.contains("Exercise 30m"))
    }

    func testExerciseAndStepsAreNotDoubleCounted() {
        let stepsOnly = DailySummaryCalculator.calculate(input(
            sleep: 7, water: 4, goal: 4, food: 100, steps: 8_000
        ))
        let both = DailySummaryCalculator.calculate(input(
            sleep: 7,
            water: 4,
            goal: 4,
            food: 100,
            steps: 8_000,
            exerciseMinutes: 30,
            exerciseEntries: 1
        ))

        XCTAssertEqual(both.score, stepsOnly.score)
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

    func testOverallBandBoundariesUseGoodBadUgly() {
        XCTAssertEqual(DailySummaryBand.classify(100), .good)
        XCTAssertEqual(DailySummaryBand.classify(80), .good)
        XCTAssertEqual(DailySummaryBand.classify(79), .bad)
        XCTAssertEqual(DailySummaryBand.classify(60), .bad)
        XCTAssertEqual(DailySummaryBand.classify(59), .ugly)
        XCTAssertEqual(DailySummaryBand.classify(0), .ugly)
    }

    func testMovementFocusUsesDocumentedWeights() {
        let noMovement = DailySummaryCalculator.calculate(
            input(sleep: 7, water: 4, goal: 4, food: 100, steps: 0),
            profile: .movementFocus
        )
        let fullMovement = DailySummaryCalculator.calculate(
            input(sleep: 7, water: 4, goal: 4, food: 100, steps: 8_000),
            profile: .movementFocus
        )

        XCTAssertEqual(noMovement.score, 65)
        XCTAssertEqual(fullMovement.score, 100)
    }

    func testFoodRoastOptOutUsesMetricNeutralFallback() {
        let result = DailySummaryCalculator.calculate(
            input(sleep: 7, water: 4, goal: 4, food: 20, steps: 8_000),
            intensity: .playful,
            foodRoastsEnabled: false
        )

        XCTAssertFalse(result.roast.localizedCaseInsensitiveContains("food"))
        XCTAssertFalse(result.roast.localizedCaseInsensitiveContains("meal"))
        XCTAssertFalse(result.roast.localizedCaseInsensitiveContains("plate"))
    }

    private func input(
        sleep: Double?,
        water: Int,
        goal: Int,
        food: Int?,
        steps: Int?,
        exerciseMinutes: Int? = nil,
        exerciseEntries: Int = 0
    ) -> DailySummaryInput {
        DailySummaryInput(
            sleepHours: sleep,
            waterBottlesLogged: water,
            waterGoalBottles: goal,
            foodScore: food,
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            exerciseEntryCount: exerciseEntries
        )
    }
}
