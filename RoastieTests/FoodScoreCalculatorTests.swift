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

    func testExposureCountsClampBoundariesAndPreserveUntrackedEntries() {
        var coffee = entry(.healthy, score: 90)
        coffee.caffeineCount = 2
        coffee.sugaryItemCount = -3

        var desserts = entry(.unhealthy, score: 20)
        desserts.caffeineCount = 0
        desserts.sugaryItemCount = 99

        let legacy = entry(.healthy, score: 90)
        let totals = FoodExposureCalculator.totals(entries: [coffee, desserts, legacy])

        XCTAssertEqual(totals.caffeineCount, 2)
        XCTAssertEqual(totals.sugaryItemCount, FoodExposureCalculator.maximumCountPerEntry)
        XCTAssertEqual(totals.trackedEntries, 2)
        XCTAssertEqual(totals.totalEntries, 3)
        XCTAssertTrue(totals.hasUntrackedEntries)
    }

    func testEmptyExposureTotalsAreCompleteAndZero() {
        XCTAssertEqual(
            FoodExposureCalculator.totals(entries: []),
            FoodExposureTotals(
                caffeineCount: 0,
                sugaryItemCount: 0,
                trackedEntries: 0,
                totalEntries: 0
            )
        )
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
