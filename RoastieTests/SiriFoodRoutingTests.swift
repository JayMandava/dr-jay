import XCTest
@testable import Roastie

final class SiriFoodRoutingTests: XCTestCase {
    @MainActor
    func testFoodPersistsOnceWithoutChangingWaterOrSleep() throws {
        let log = makeLog()
        var saves = 0
        let entry = try FoodEntryPersistence.insert(description: "  Paneer dosa  ", in: log,
            save: { saves += 1; return true })
        XCTAssertEqual(entry.text, "Paneer dosa")
        XCTAssertEqual(entry.verdict, .unanalyzed)
        XCTAssertEqual(log.foodEntries?.map(\.id), [entry.id])
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(log.waterBottlesLogged, 2)
        XCTAssertEqual(log.sleepHours, 7)
        XCTAssertTrue(log.waterTimestamps.isEmpty)
        XCTAssertTrue(log.checkIns.isEmpty)
    }

    @MainActor
    func testBlankFoodDoesNotSaveAnything() {
        let log = makeLog()
        var saves = 0
        XCTAssertThrowsError(try FoodEntryPersistence.insert(description: " \n\t ", in: log,
            save: { saves += 1; return true }))
        XCTAssertEqual(saves, 0)
        XCTAssertTrue((log.foodEntries ?? []).isEmpty)
        XCTAssertEqual(log.waterBottlesLogged, 2)
        XCTAssertEqual(log.sleepHours, 7)
    }

    @MainActor
    func testFailedFoodSaveRestoresEntriesAndScoringCache() {
        let log = makeLog()
        let known = FoodEntry(text: "Known meal", timestamp: .distantPast,
            verdict: .healthy, assessment: nil, roast: nil, qualityScore: 90)
        log.foodEntries = [known]
        log.foodScore = 90
        log.foodScoreSummary = "Existing summary"
        log.foodScoreIsCurrent = true
        log.foodScoreVersion = FoodScoreCalculator.version
        var saves = 0
        XCTAssertThrowsError(try FoodEntryPersistence.insert(description: "New meal", in: log,
            save: { saves += 1; return false }))
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(log.foodEntries, [known])
        XCTAssertEqual(log.foodScore, 90)
        XCTAssertEqual(log.foodScoreSummary, "Existing summary")
        XCTAssertEqual(log.foodScoreIsCurrent, true)
        XCTAssertEqual(log.foodScoreVersion, FoodScoreCalculator.version)
        XCTAssertEqual(log.waterBottlesLogged, 2)
        XCTAssertEqual(log.sleepHours, 7)
    }

    @MainActor
    func testNewUnassessedFoodPreservesPartialKnownScore() throws {
        let log = makeLog()
        log.foodEntries = [FoodEntry(text: "Known", timestamp: .distantPast,
            verdict: .healthy, assessment: nil, roast: nil, qualityScore: 90)]
        _ = try FoodEntryPersistence.insert(description: "Unfamiliar meal", in: log, save: { true })
        XCTAssertEqual(log.foodScoreAggregate.score, 90)
        XCTAssertTrue(log.foodScoreAggregate.isPartial)
        XCTAssertEqual(log.foodEntries?.count, 2)
    }

    @MainActor
    func testCancelledWaterConfirmationNeverInvokesSave() async {
        let log = makeLog()
        var saves = 0
        do {
            _ = try await SiriWaterConfirmation.run(
                confirm: { throw CancellationError() },
                save: {
                    saves += 1
                    return try SiriLogging.perform(.water, log: log, onboardingComplete: true, save: { true })
                }
            )
            XCTFail("Cancellation must propagate")
        } catch {}
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(log.waterBottlesLogged, 2)
        XCTAssertTrue((log.foodEntries ?? []).isEmpty)
    }

    @MainActor
    func testConfirmedWaterLogsExactlyOnceAfterConfirmation() async throws {
        let log = makeLog()
        var confirmed = false
        var saves = 0
        _ = try await SiriWaterConfirmation.run(
            confirm: { confirmed = true },
            save: {
                XCTAssertTrue(confirmed)
                saves += 1
                return try SiriLogging.perform(.water, log: log, onboardingComplete: true, save: { true })
            }
        )
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(log.waterBottlesLogged, 3)
        XCTAssertTrue((log.foodEntries ?? []).isEmpty)
        XCTAssertEqual(log.sleepHours, 7)
    }

    @MainActor
    private func makeLog() -> DailyLog {
        let date = TestSupport.date(23)
        let log = DailyLog(dayKey: date.dayKey, date: date, waterGoalBottles: 4)
        log.waterBottlesLogged = 2
        log.sleepHours = 7
        return log
    }
}
