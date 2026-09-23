import XCTest
@testable import Roastie

final class FoodScoreCalculatorTests: XCTestCase {
    func testEmptyAndUnanalyzedLogsHaveNoScore() {
        XCTAssertNil(FoodScoreCalculator.score(entries: []))
        XCTAssertNil(FoodScoreCalculator.score(entries: [entry(.unanalyzed, score: nil)]))
        XCTAssertNil(FoodScoreCalculator.score(entries: [
            entry(.healthy, score: 90),
            entry(.unanalyzed, score: nil)
        ]))
    }

    func testVerdictRangesClampModelBoundaryViolations() {
        XCTAssertEqual(FoodScoreCalculator.score(entries: [entry(.healthy, score: -20)]), 80)
        XCTAssertEqual(FoodScoreCalculator.score(entries: [entry(.healthy, score: 140)]), 100)
        XCTAssertEqual(FoodScoreCalculator.score(entries: [entry(.unhealthy, score: -20)]), 0)
        XCTAssertEqual(FoodScoreCalculator.score(entries: [entry(.unhealthy, score: 140)]), 59)
    }

    func testThreeHealthyAndOneUnhealthyCannotBeUgly() {
        let entries = [
            entry(.healthy, score: 80),
            entry(.healthy, score: 80),
            entry(.healthy, score: 80),
            entry(.unhealthy, score: 0)
        ]

        let score = FoodScoreCalculator.score(entries: entries)

        XCTAssertEqual(score, 60)
        XCTAssertEqual(score.map(FoodScoreBand.classify), .bad)
    }

    func testScoreIsIndependentOfEntryOrder() {
        let first = entry(.healthy, score: 96)
        let middle = entry(.unhealthy, score: 22)
        let last = entry(.healthy, score: 84)

        XCTAssertEqual(
            FoodScoreCalculator.score(entries: [first, middle, last]),
            FoodScoreCalculator.score(entries: [last, first, middle])
        )
    }

    func testLegacyEntriesUseStableVerdictDefaults() {
        XCTAssertEqual(FoodScoreCalculator.score(entries: [entry(.healthy, score: nil)]), 90)
        XCTAssertEqual(FoodScoreCalculator.score(entries: [entry(.unhealthy, score: nil)]), 30)
    }

    private func entry(_ verdict: FoodVerdict, score: Int?) -> FoodEntry {
        FoodEntry(
            text: "Test food",
            timestamp: .distantPast,
            verdict: verdict,
            assessment: nil,
            roast: nil,
            qualityScore: score
        )
    }
}
