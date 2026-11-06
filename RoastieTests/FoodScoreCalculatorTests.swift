import XCTest
@testable import Roastie

final class FoodScoreCalculatorTests: XCTestCase {
    func testEmptyAndUnanalyzedLogsHaveNoScore() {
        XCTAssertNil(FoodScoreCalculator.score(entries: []))
        XCTAssertNil(FoodScoreCalculator.score(entries: [entry(.unanalyzed, score: nil)]))
        XCTAssertEqual(FoodScoreCalculator.score(entries: [
            entry(.healthy, score: 90),
            entry(.unanalyzed, score: nil)
        ]), 90)
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

    func testMixedEntriesPreserveKnownMeanAndCoverage() {
        let unknown = entry(.unanalyzed, score: 100)
        let aggregate = FoodScoreCalculator.aggregate(entries: [
            entry(.healthy, score: 90), entry(.unhealthy, score: 30), unknown
        ])
        XCTAssertEqual(aggregate.score, 60)
        XCTAssertEqual(aggregate.assessedEntryCount, 2)
        XCTAssertEqual(aggregate.totalEntryCount, 3)
        XCTAssertEqual(aggregate.unresolvedEntryIDs, [unknown.id])
        XCTAssertTrue(aggregate.isPartial)
        XCTAssertFalse(aggregate.isComplete)
    }

    func testEmptyAndAllUnknownCoverageIsNotCompleteOrZero() {
        for entries in [[], [entry(.unanalyzed, score: nil)]] {
            let aggregate = FoodScoreCalculator.aggregate(entries: entries)
            XCTAssertNil(aggregate.score)
            XCTAssertEqual(aggregate.assessedEntryCount, 0)
            XCTAssertFalse(aggregate.isPartial)
            XCTAssertFalse(aggregate.isComplete)
        }
    }

    func testValidZeroIsAssessedAndUnknownIsExcluded() {
        let aggregate = FoodScoreCalculator.aggregate(entries: [
            entry(.unhealthy, score: 0), entry(.unanalyzed, score: nil)
        ])
        XCTAssertEqual(aggregate.score, 0)
        XCTAssertEqual(aggregate.assessedEntryCount, 1)
        XCTAssertTrue(aggregate.isPartial)
    }

    func testCorrectionAndDeletionRestoreCompleteCoverage() {
        let known = entry(.healthy, score: 90)
        var unresolved = entry(.unanalyzed, score: nil)
        XCTAssertTrue(FoodScoreCalculator.aggregate(entries: [known, unresolved]).isPartial)
        unresolved.verdict = .unhealthy
        unresolved.qualityScore = 30
        let corrected = FoodScoreCalculator.aggregate(entries: [known, unresolved])
        XCTAssertEqual(corrected.score, 60)
        XCTAssertTrue(corrected.isComplete)
        XCTAssertTrue(FoodScoreCalculator.aggregate(entries: [known]).isComplete)
    }

    func testLateAssessmentCannotOverwriteCorrectionOrResurrectDeletion() {
        let original = entry(.unanalyzed, score: nil)
        var assessed = original
        assessed.verdict = .healthy
        assessed.qualityScore = 90
        var corrected = original
        corrected.verdict = .unhealthy
        corrected.wasManuallyCorrected = true
        XCTAssertNil(FoodEntryAssessmentUpdate.applying(assessed, to: original, in: [corrected]))
        XCTAssertNil(FoodEntryAssessmentUpdate.applying(assessed, to: original, in: []))
        var edited = original
        edited.text = "Different meal"
        XCTAssertNil(FoodEntryAssessmentUpdate.applying(assessed, to: original, in: [edited]))
    }

    func testAssessmentPreservesConcurrentlyAddedEntries() throws {
        let original = entry(.unanalyzed, score: nil)
        let other = entry(.unhealthy, score: 30)
        var assessed = original
        assessed.verdict = .healthy
        assessed.qualityScore = 90
        let updated = try XCTUnwrap(FoodEntryAssessmentUpdate.applying(
            assessed, to: original, in: [original, other]
        ))
        XCTAssertEqual(updated, [assessed, other])
        XCTAssertEqual(FoodScoreCalculator.aggregate(entries: updated).score, 60)
        XCTAssertTrue(FoodScoreCalculator.aggregate(entries: updated).isComplete)
    }

    func testPartialDayDoesNotGenerateAnAllFoodSummary() async {
        let result = await FoodAnalyzer.scoreDay(
            entries: [entry(.healthy, score: 90), entry(.unanalyzed, score: nil)],
            intensity: .gentle, roastsEnabled: true
        )
        XCTAssertEqual(result?.score, 90)
        XCTAssertNil(result?.summary)
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

