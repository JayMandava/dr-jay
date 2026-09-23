import XCTest
@testable import Roastie

final class StreakCalculatorTests: XCTestCase {
    func testIncompleteTodayPreservesStreakThroughYesterday() {
        let logs = [
            perfectLog(day: 20),
            perfectLog(day: 21),
            perfectLog(day: 22),
            incompleteLog(day: 23),
        ]

        let stats = StreakCalculator.calculate(
            logs: logs,
            referenceDate: TestSupport.date(23),
            calendar: TestSupport.calendar
        )

        XCTAssertEqual(stats, StreakStats(current: 3, longest: 3, perfectDays: 3))
    }

    func testGapBreaksCurrentButKeepsLongestStreak() {
        let logs = [
            perfectLog(day: 18),
            perfectLog(day: 19),
            incompleteLog(day: 20),
            perfectLog(day: 22),
        ]

        let stats = StreakCalculator.calculate(
            logs: logs,
            referenceDate: TestSupport.date(23),
            calendar: TestSupport.calendar
        )

        XCTAssertEqual(stats.current, 1)
        XCTAssertEqual(stats.longest, 2)
        XCTAssertEqual(stats.perfectDays, 3)
    }

    private func perfectLog(day: Int) -> DailyLog {
        let log = DailyLog(dayKey: "2026-09-\(day)", date: TestSupport.date(day), waterGoalBottles: 4)
        log.sleepHours = 7
        log.waterBottlesLogged = 4
        return log
    }

    private func incompleteLog(day: Int) -> DailyLog {
        DailyLog(dayKey: "2026-09-\(day)", date: TestSupport.date(day), waterGoalBottles: 4)
    }
}
