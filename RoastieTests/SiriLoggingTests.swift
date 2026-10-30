import XCTest
import SwiftData
@testable import Roastie

final class SiriLoggingTests: XCTestCase {
    @MainActor
    func testWaterSuccessSavesOnceAndReturnsPersistedTotalWithoutSnapshot() throws {
        let log = makeLog()
        var saves = 0
        let receipt = try SiriLogging.perform(.water, log: log, onboardingComplete: true,
            now: TestSupport.date(23), window: .afternoon, save: { saves += 1; return true })
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(log.waterBottlesLogged, 1)
        XCTAssertEqual(log.waterTimestamps, [TestSupport.date(23)])
        XCTAssertEqual(log.checkIns.last?.window, .afternoon)
        XCTAssertEqual(log.checkIns.last?.wasGeneratedByModel, false)
        XCTAssertTrue(receipt.dialog.contains("1 of 4 bottles today"))
        XCTAssertTrue(receipt.changed)
    }

    @MainActor
    func testWaterSaveFailureThrowsAndRollsBack() {
        let log = makeLog()
        let before = log.checkIns
        XCTAssertThrowsError(try SiriLogging.perform(.water, log: log, onboardingComplete: true, save: { false }))
        XCTAssertEqual(log.waterBottlesLogged, 0)
        XCTAssertTrue(log.waterTimestamps.isEmpty)
        XCTAssertEqual(log.checkIns, before)
    }

    @MainActor
    func testSleepSaveFailureRestoresHealthSourceAndHours() {
        let log = makeLog()
        log.sleepHours = 7
        log.sleepSource = "healthkit"
        XCTAssertThrowsError(try SiriLogging.perform(.sleep(hours: 1), log: log,
            onboardingComplete: true, save: { false }))
        XCTAssertEqual(log.sleepHours, 7)
        XCTAssertEqual(log.sleepSource, "healthkit")
        XCTAssertTrue(log.checkIns.isEmpty)
    }

    @MainActor
    func testSleepSuccessIsAdditiveAndManual() throws {
        let log = makeLog()
        log.sleepHours = 6
        log.sleepSource = "healthkit"
        let receipt = try SiriLogging.perform(.sleep(hours: 1.5), log: log,
            onboardingComplete: true, save: { true })
        XCTAssertEqual(log.sleepHours, 7.5)
        XCTAssertEqual(log.sleepSource, "manual")
        XCTAssertTrue(receipt.dialog.contains("7.5 hours total"))
    }

    @MainActor
    func testQuarterHourReceiptsPreserveSupportedDurationPrecision() throws {
        for (hours, spoken) in [(0.25, "0.25"), (0.75, "0.75")] {
            let log = makeLog()
            let receipt = try SiriLogging.perform(.sleep(hours: hours), log: log,
                onboardingComplete: true, save: { true })
            XCTAssertEqual(log.sleepHours, hours)
            XCTAssertTrue(receipt.dialog.contains("\(spoken) hours total"))
            XCTAssertTrue(SiriLogging.sleepStatus(log: log, now: TestSupport.date(23)).contains("\(spoken) hours"))
        }
    }

    @MainActor
    func testInvalidDurationsNeverSaveOrMutate() {
        for value in [0, -1, 25, Double.infinity, Double.nan] {
            let log = makeLog()
            var saves = 0
            XCTAssertThrowsError(try SiriLogging.perform(.sleep(hours: value), log: log,
                onboardingComplete: true, save: { saves += 1; return true }))
            XCTAssertEqual(saves, 0)
            XCTAssertNil(log.sleepHours)
            XCTAssertTrue(log.checkIns.isEmpty)
        }
    }

    @MainActor
    func testOverflowNeverSaves() {
        let log = makeLog()
        log.sleepHours = .infinity
        var saves = 0
        XCTAssertThrowsError(try SiriLogging.perform(.sleep(hours: 1), log: log,
            onboardingComplete: true, save: { saves += 1; return true }))
        XCTAssertEqual(saves, 0)
    }

    @MainActor
    func testOnboardingRequiredDoesNotMutateOrSave() {
        let log = makeLog()
        var saves = 0
        XCTAssertThrowsError(try SiriLogging.perform(.water, log: log,
            onboardingComplete: false, save: { saves += 1; return true }))
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(log.waterBottlesLogged, 0)
    }

    @MainActor
    func testHealthKitConfirmationConflictIsTruthfullyUnchanged() throws {
        let log = makeLog()
        log.sleepHours = 7
        log.sleepSource = "healthkit"
        var saves = 0
        let receipt = try SiriLogging.perform(.confirmSleep(met: false), log: log,
            onboardingComplete: true, save: { saves += 1; return true })
        XCTAssertFalse(receipt.changed)
        XCTAssertTrue(receipt.dialog.contains("Health records 7.0 hours"))
        XCTAssertTrue(receipt.dialog.contains("No changes made"))
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(log.sleepHours, 7)
        XCTAssertEqual(log.sleepSource, "healthkit")
        XCTAssertTrue(log.checkIns.isEmpty)
    }

    @MainActor
    func testGoalConfirmationLabelsLegacyEstimate() throws {
        let log = makeLog()
        let receipt = try SiriLogging.perform(.confirmSleep(met: true), log: log,
            onboardingComplete: true, save: { true })
        XCTAssertEqual(log.sleepHours, AppConfig.sleepGoalHours)
        XCTAssertTrue(receipt.dialog.contains("estimate"))
    }

    @MainActor
    func testGoalConfirmationSaveFailureRollsBack() {
        let log = makeLog()
        XCTAssertThrowsError(try SiriLogging.perform(.confirmSleep(met: true), log: log,
            onboardingComplete: true, save: { false }))
        XCTAssertNil(log.sleepHours)
        XCTAssertEqual(log.sleepSource, "unknown")
        XCTAssertTrue(log.checkIns.isEmpty)
    }

    @MainActor
    func testStatusRejectsYesterdayAndHandlesNoColdStartRecord() {
        let log = makeLog()
        log.sleepHours = 8
        log.waterBottlesLogged = 4
        let tomorrow = TestSupport.date(24)
        XCTAssertTrue(SiriLogging.waterStatus(log: log, now: tomorrow).contains("No water data"))
        XCTAssertEqual(SiriLogging.sleepStatus(log: log, now: tomorrow), "No sleep data yet today.")
        XCTAssertTrue(SiriLogging.waterStatus(log: nil, now: tomorrow).contains("No water data"))
        XCTAssertEqual(SiriLogging.sleepStatus(log: nil, now: tomorrow), "No sleep data yet today.")
    }

    @MainActor
    func testCurrentDayStatusReadsActualValues() {
        let log = makeLog()
        log.sleepHours = 7
        log.waterBottlesLogged = 2
        XCTAssertTrue(SiriLogging.waterStatus(log: log, now: TestSupport.date(23)).contains("2 of 4"))
        XCTAssertTrue(SiriLogging.sleepStatus(log: log, now: TestSupport.date(23)).contains("7.0 hours"))
    }

    @MainActor
    func testRepeatedIntentionalInvocationsAreNotSilentlyDeduplicated() throws {
        let log = makeLog()
        var saves = 0
        for _ in 0..<2 {
            _ = try SiriLogging.perform(.water, log: log, onboardingComplete: true,
                save: { saves += 1; return true })
        }
        XCTAssertEqual(log.waterBottlesLogged, 2)
        XCTAssertEqual(saves, 2)
    }

    func testAllSiriDurationOptionsAreFiniteAndSupported() {
        let durations: [SleepDurationOption] = [
            .fifteenMinutes, .thirtyMinutes, .fortyFiveMinutes, .oneHour,
            .ninetyMinutes, .twoHours, .threeHours, .fourHours, .fiveHours,
            .sixHours, .sevenHours, .eightHours, .nineHours, .tenHours,
            .elevenHours, .twelveHours
        ]
        XCTAssertEqual(Set(durations.map(\.hours)).count, durations.count)
        for duration in durations {
            XCTAssertTrue(duration.hours.isFinite)
            XCTAssertTrue((0.25...12).contains(duration.hours))
        }
    }

    @MainActor
    func testSavedSiriEntriesSurviveFreshContextWithoutCachedSnapshot() throws {
        let schema = Schema([DailyLog.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let writer = ModelContext(container)
        let log = makeLog()
        writer.insert(log)
        for action in [SiriLogAction.water, .sleep(hours: 7)] {
            _ = try SiriLogging.perform(action, log: log, onboardingComplete: true,
                save: {
                    do { try writer.save(); return true }
                    catch { return false }
                })
        }
        let reader = ModelContext(container)
        let persisted = try XCTUnwrap(reader.fetch(FetchDescriptor<DailyLog>()).first)
        XCTAssertEqual(persisted.waterBottlesLogged, 1)
        XCTAssertEqual(persisted.sleepHours, 7)
        XCTAssertTrue(SiriLogging.waterStatus(log: persisted, now: TestSupport.date(23)).contains("1 of 4"))
        XCTAssertTrue(SiriLogging.sleepStatus(log: persisted, now: TestSupport.date(23)).contains("7.0 hours"))
        XCTAssertEqual(persisted.checkIns.count, 2)
    }

    @MainActor
    private func makeLog() -> DailyLog {
        let date = TestSupport.date(23)
        return DailyLog(dayKey: date.dayKey, date: date, waterGoalBottles: 4)
    }
}
