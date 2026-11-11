import XCTest
import SwiftData
@testable import Roastie

final class SurroundingsBonusPersistenceTests: XCTestCase {
    private var previousSettings = AppSettings()

    override func setUp() {
        super.setUp()
        previousSettings = SharedStore.loadSettings()
    }

    override func tearDown() {
        SharedStore.save(previousSettings)
        super.tearDown()
    }

    private func setAwareness(_ enabled: Bool) {
        var settings = previousSettings
        settings.surroundingsAwarenessEnabled = enabled
        SharedStore.save(settings)
    }

    private func storeURL(_ name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appending(path: name)
    }

    private func todayLog(logged: Int, goal: Int = 4, in context: ModelContext) -> DailyLog {
        let now = Date()
        let log = DailyLog(dayKey: now.dayKey, date: now.startOfDay, waterGoalBottles: goal)
        log.waterBottlesLogged = logged
        context.insert(log)
        return log
    }

    @MainActor
    func testDisabledDoesNothingAndWaterBonusClaimsOnlyOnceWhenGoalIsMet() async throws {
        let url = try storeURL("water.store")
        let today = Date().dayKey
        var earnedAt: Date?
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let coordinator = DayCoordinator(context: context)
            setAwareness(false)
            let disabledWater = await coordinator.claimSurroundingsWaterBonus()
            let disabledFood = await coordinator.claimSurroundingsFoodPick(idea: "Idea")
            XCTAssertFalse(disabledWater)
            XCTAssertFalse(disabledFood)
            XCTAssertTrue(try context.fetch(FetchDescriptor<DailyLog>()).isEmpty)

            setAwareness(true)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let old = DailyLog(dayKey: yesterday.dayKey, date: yesterday.startOfDay, waterGoalBottles: 4)
            old.waterBottlesLogged = 4
            context.insert(old)
            let log = todayLog(logged: 3, in: context)
            try context.save()
            let short = await coordinator.claimSurroundingsWaterBonus()
            XCTAssertFalse(short, "three of four bottles is not the whole suggestion")
            XCTAssertNil(log.surroundingsBonusEarnedAt)

            log.waterBottlesLogged = 4
            try context.save()
            let first = await coordinator.claimSurroundingsWaterBonus()
            let second = await coordinator.claimSurroundingsWaterBonus()
            XCTAssertTrue(first)
            XCTAssertFalse(second)
            let logs = try context.fetch(FetchDescriptor<DailyLog>())
            earnedAt = try XCTUnwrap(logs.first { $0.dayKey == today }?.surroundingsBonusEarnedAt)
            XCTAssertNil(logs.first { $0.dayKey == yesterday.dayKey }?.surroundingsBonusEarnedAt)
        }
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let logs = try context.fetch(FetchDescriptor<DailyLog>())
            XCTAssertEqual(logs.first { $0.dayKey == today }?.surroundingsBonusEarnedAt, earnedAt)
            let again = await DayCoordinator(context: context).claimSurroundingsWaterBonus()
            XCTAssertFalse(again)
        }
    }

    @MainActor
    func testWaterBonusNeedsALogThatReachedTheGoalAndNeverCreatesOne() async throws {
        setAwareness(true)
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let coordinator = DayCoordinator(context: context)
        let result = await coordinator.claimSurroundingsWaterBonus()
        XCTAssertFalse(result)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyLog>()).isEmpty)
        let invalidGoal = todayLog(logged: 0, goal: 0, in: context)
        try context.save()
        let invalid = await coordinator.claimSurroundingsWaterBonus()
        XCTAssertFalse(invalid)
        XCTAssertNil(invalidGoal.surroundingsBonusEarnedAt)
    }

    @MainActor
    func testFoodPicksCountOncePerIdeaAndPersist() async throws {
        setAwareness(true)
        let url = try storeURL("food.store")
        let today = Date().dayKey
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let coordinator = DayCoordinator(context: context)
            let second = await coordinator.claimSurroundingsFoodPick(idea: "Dal and rice")
            let repeated = await coordinator.claimSurroundingsFoodPick(idea: " Dal and rice ")
            let first = await coordinator.claimSurroundingsFoodPick(idea: "Add a banana as a cool snack.")
            XCTAssertTrue(second)
            XCTAssertFalse(repeated)
            XCTAssertTrue(first)
            for invalid in ["", "   ", String(repeating: "x", count: 201)] {
                let result = await coordinator.claimSurroundingsFoodPick(idea: invalid)
                XCTAssertFalse(result)
            }
            let logs = try context.fetch(FetchDescriptor<DailyLog>())
            XCTAssertEqual(logs.first { $0.dayKey == today }?.surroundingsFoodIdeas, ["Dal and rice", "Add a banana as a cool snack."])
            XCTAssertNil(logs.first { $0.dayKey == today }?.surroundingsBonusEarnedAt)
        }
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let logs = try context.fetch(FetchDescriptor<DailyLog>())
            XCTAssertEqual(logs.first { $0.dayKey == today }?.surroundingsFoodIdeas, ["Dal and rice", "Add a banana as a cool snack."])
            let again = await DayCoordinator(context: context).claimSurroundingsFoodPick(idea: "Dal and rice")
            XCTAssertFalse(again)
        }
    }

    /// A pick must stay counted when a later weather check suggests different ideas,
    /// and a day can never exceed the food cap however many ideas are tried.
    @MainActor
    func testPickSurvivesWeatherChangeAndIsCapped() async throws {
        setAwareness(true)
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let coordinator = DayCoordinator(context: context)
        let warm = SurroundingsSuggestion(kind: .warm, title: "", detail: "").foodPointers(in: .southAsia)
        let cool = SurroundingsSuggestion(kind: .cool, title: "", detail: "").foodPointers(in: .southAsia)
        let picked = try XCTUnwrap(warm.first)
        let claimed = await coordinator.claimSurroundingsFoodPick(idea: picked)
        XCTAssertTrue(claimed)
        for idea in cool + warm {
            _ = await coordinator.claimSurroundingsFoodPick(idea: idea)
        }
        let log = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyLog>()).first)
        XCTAssertEqual(log.surroundingsFoodIdeas?.count, SurroundingsSuggestion.foodSlotCount)
        XCTAssertEqual(log.surroundingsFoodIdeas?.first, picked)
    }

    @MainActor
    func testClaimsDoNotChangeScoreVerdictGoalsOrStreak() async throws {
        setAwareness(true)
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let now = Date()
        let log = todayLog(logged: 4, in: context)
        log.sleepHours = 7
        log.foodScore = 80
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
        let coordinator = DayCoordinator(context: context)
        let water = await coordinator.claimSurroundingsWaterBonus()
        let food = await coordinator.claimSurroundingsFoodPick(idea: "Idea")
        XCTAssertTrue(water)
        XCTAssertTrue(food)
        XCTAssertNotNil(log.surroundingsBonusEarnedAt)
        XCTAssertEqual(log.surroundingsFoodIdeas, ["Idea"])
        XCTAssertEqual(profiles.map { summary($0) }, before)
        XCTAssertEqual(StreakCalculator.calculate(logs: [log], referenceDate: now), streak)
        XCTAssertEqual(log.sleepGoalMet, sleepGoalMet)
        XCTAssertEqual(log.waterProgress, waterProgress)
        XCTAssertEqual(log.waterGoalBottles, 4)
        XCTAssertEqual(log.foodScore, 80)
        XCTAssertEqual(SharedStore.loadSettings().dailyScoreProfile, previousSettings.dailyScoreProfile)
    }

    @MainActor
    func testSaveFailureDoesNotAwardEitherBonus() async throws {
        setAwareness(true)
        let url = try storeURL("readonly.store")
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            _ = todayLog(logged: 4, in: context)
            try context.save()
        }
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url, allowsSave: false))
        let context = ModelContext(container)
        let log = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyLog>()).first)
        let coordinator = DayCoordinator(context: context)
        let water = await coordinator.claimSurroundingsWaterBonus()
        let food = await coordinator.claimSurroundingsFoodPick(idea: "Idea")
        XCTAssertFalse(water)
        XCTAssertFalse(food)
        XCTAssertNil(log.surroundingsBonusEarnedAt)
        XCTAssertNil(log.surroundingsFoodIdeas)
    }
}
