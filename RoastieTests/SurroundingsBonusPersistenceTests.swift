import XCTest
import SwiftData
@testable import Roastie

final class SurroundingsBonusPersistenceTests: XCTestCase {
    @MainActor
    func testDisabledDoesNotCreateLogAndRepeatedClaimPersistsOnlyOnce() async throws {
        let previousSettings = SharedStore.loadSettings()
        defer { SharedStore.save(previousSettings) }
        var settings = previousSettings
        settings.surroundingsAwarenessEnabled = false
        SharedStore.save(settings)
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "bonus.store")
        let today = Date().dayKey
        var earnedAt: Date?
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let coordinator = DayCoordinator(context: context)
            let disabledResult = await coordinator.claimSurroundingsBonus()
            XCTAssertFalse(disabledResult)
            XCTAssertTrue(try context.fetch(FetchDescriptor<DailyLog>()).isEmpty)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            context.insert(DailyLog(dayKey: yesterday.dayKey, date: yesterday.startOfDay, waterGoalBottles: 4))
            try context.save()
            settings.surroundingsAwarenessEnabled = true
            SharedStore.save(settings)
            let firstResult = await coordinator.claimSurroundingsBonus()
            let secondResult = await coordinator.claimSurroundingsBonus()
            XCTAssertTrue(firstResult)
            XCTAssertFalse(secondResult)
            let logs = try context.fetch(FetchDescriptor<DailyLog>())
            earnedAt = try XCTUnwrap(logs.first { $0.dayKey == today }?.surroundingsBonusEarnedAt)
            XCTAssertNil(logs.first { $0.dayKey == yesterday.dayKey }?.surroundingsBonusEarnedAt)
            let log = try XCTUnwrap(logs.first { $0.dayKey == today })
            XCTAssertEqual(log.waterBottlesLogged, 0)
            XCTAssertNil(log.sleepHours)
            XCTAssertTrue(log.checkIns.isEmpty)
        }
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let logs = try context.fetch(FetchDescriptor<DailyLog>())
            XCTAssertEqual(logs.first { $0.dayKey == today }?.surroundingsBonusEarnedAt, earnedAt)
            let result = await DayCoordinator(context: context).claimSurroundingsBonus()
            XCTAssertFalse(result)
        }
    }

    @MainActor
    func testClaimDoesNotChangeScoreVerdictGoalsOrStreak() async throws {
        let previousSettings = SharedStore.loadSettings()
        defer { SharedStore.save(previousSettings) }
        var settings = previousSettings
        settings.surroundingsAwarenessEnabled = true
        SharedStore.save(settings)
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let now = Date()
        let log = DailyLog(dayKey: now.dayKey, date: now.startOfDay, waterGoalBottles: 4)
        log.sleepHours = 7
        log.waterBottlesLogged = 4
        log.foodScore = 80
        context.insert(log)
        try context.save()
        func summary(_ profile: DailyScoreProfile) -> DailySummaryResult {
            DailySummaryCalculator.calculate(DailySummaryInput(
                sleepHours: log.sleepHours, waterBottlesLogged: log.waterBottlesLogged,
                waterGoalBottles: log.waterGoalBottles, foodScore: log.foodScore,
                steps: 4_000, exerciseMinutes: nil, exerciseEntryCount: 0
            ), profile: profile)
        }
        let profiles = DailyScoreProfile.allCases
        let before = profiles.map { summary($0) }
        let streak = StreakCalculator.calculate(logs: [log], referenceDate: now)
        let sleepGoalMet = log.sleepGoalMet
        let waterProgress = log.waterProgress
        let result = await DayCoordinator(context: context).claimSurroundingsBonus()
        XCTAssertTrue(result)
        XCTAssertNotNil(log.surroundingsBonusEarnedAt)
        XCTAssertEqual(profiles.map { summary($0) }, before)
        XCTAssertEqual(StreakCalculator.calculate(logs: [log], referenceDate: now), streak)
        XCTAssertEqual(log.sleepGoalMet, sleepGoalMet)
        XCTAssertEqual(log.waterProgress, waterProgress)
        XCTAssertEqual(log.waterGoalBottles, 4)
        XCTAssertEqual(log.foodScore, 80)
        XCTAssertEqual(SharedStore.loadSettings().dailyScoreProfile, previousSettings.dailyScoreProfile)
    }

    @MainActor
    func testSaveFailureDoesNotAwardBonus() async throws {
        let previousSettings = SharedStore.loadSettings()
        defer { SharedStore.save(previousSettings) }
        var settings = previousSettings
        settings.surroundingsAwarenessEnabled = true
        SharedStore.save(settings)
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            context.insert(DailyLog(dayKey: Date().dayKey, date: Date().startOfDay, waterGoalBottles: 4))
            try context.save()
        }
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url, allowsSave: false))
        let context = ModelContext(container)
        let log = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyLog>()).first)
        let result = await DayCoordinator(context: context).claimSurroundingsBonus()
        XCTAssertFalse(result)
        XCTAssertNil(log.surroundingsBonusEarnedAt)
    }
}
