import XCTest
@testable import Roastie

final class LongitudinalInsightsCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testSevenLoggedDaysCreateUsableBaseline() {
        let reference = date(2026, 9, 29)
        let logs = (0..<7).map { offset in
            log(daysBefore: offset, reference: reference, sleep: 7, water: 4, food: 85)
        }

        let report = LongitudinalInsightsCalculator.calculate(
            logs: logs,
            period: .sevenDays,
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertTrue(report.hasMinimumData)
        XCTAssertFalse(report.hasComparisonBaseline)
        XCTAssertEqual(report.trackedDays, 7)
        XCTAssertEqual(report.completeDays, 7)
    }

    func testCurrentWindowImprovementUsesPreviousWindow() {
        let reference = date(2026, 9, 29)
        let current = (0..<7).map { offset in
            log(daysBefore: offset, reference: reference, sleep: 7, water: 4, food: 90)
        }
        let previous = (7..<14).map { offset in
            log(daysBefore: offset, reference: reference, sleep: 5, water: 1, food: 40)
        }

        let report = LongitudinalInsightsCalculator.calculate(
            logs: current + previous,
            period: .sevenDays,
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertTrue(report.hasComparisonBaseline)
        XCTAssertEqual(report.metrics.first { $0.id == "sleep" }?.direction, .improving)
        XCTAssertEqual(report.metrics.first { $0.id == "water" }?.direction, .improving)
        XCTAssertEqual(report.metrics.first { $0.id == "food" }?.direction, .improving)
    }

    func testExposureTotalsUseConfirmedFoodAnalysis() {
        let reference = date(2026, 9, 29)
        let log = log(daysBefore: 0, reference: reference, sleep: 7, water: 4, food: 80)
        log.foodEntries = [
            FoodEntry(
                text: "Coffee and cake",
                timestamp: reference,
                verdict: .unhealthy,
                assessment: nil,
                roast: nil,
                caffeineCount: 1,
                sugaryItemCount: 1
            )
        ]

        let report = LongitudinalInsightsCalculator.calculate(
            logs: [log],
            period: .sevenDays,
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(report.caffeineTotal, 1)
        XCTAssertEqual(report.sugaryItemTotal, 1)
        XCTAssertEqual(report.exposureDays, 1)
    }

    func testSparseMetricDoesNotClaimDirectionFromOverallCoverage() {
        let reference = date(2026, 9, 29)
        let current = (0..<7).map { offset in
            log(daysBefore: offset, reference: reference, sleep: 7, water: 4, food: 90)
        }
        let previous = (7..<14).map { offset in
            log(daysBefore: offset, reference: reference, sleep: 7, water: 4, food: 40)
        }
        current.dropFirst().forEach {
            $0.foodScore = nil
            $0.foodScoreIsCurrent = true
        }
        previous.dropFirst().forEach {
            $0.foodScore = nil
            $0.foodScoreIsCurrent = true
        }

        let report = LongitudinalInsightsCalculator.calculate(
            logs: current + previous,
            period: .sevenDays,
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertTrue(report.hasComparisonBaseline)
        XCTAssertEqual(report.metrics.first { $0.id == "food" }?.direction, .buildingBaseline)
    }

    func testExerciseIsReportedWithoutBecomingAWeakestMetric() {
        let reference = date(2026, 9, 29)
        let log = log(daysBefore: 0, reference: reference, sleep: 7, water: 4, food: 90)
        log.exerciseEntries = [ExerciseEntry(
            text: "30-minute run",
            timestamp: reference,
            category: .cardio,
            durationMinutes: 30
        )]

        let report = LongitudinalInsightsCalculator.calculate(
            logs: [log],
            period: .sevenDays,
            referenceDate: reference,
            calendar: calendar
        )

        let exercise = report.metrics.first { $0.id == "exercise" }
        XCTAssertEqual(exercise?.value, "1")
        XCTAssertEqual(exercise?.direction, .context)
        XCTAssertNotEqual(report.primaryFocus, "Exercise")
    }

    private func log(
        daysBefore: Int,
        reference: Date,
        sleep: Double,
        water: Int,
        food: Int
    ) -> DailyLog {
        let day = calendar.date(byAdding: .day, value: -daysBefore, to: reference)!
        let log = DailyLog(dayKey: day.dayKey, date: day, waterGoalBottles: 4)
        log.sleepHours = sleep
        log.waterBottlesLogged = water
        log.foodScore = food
        log.foodScoreIsCurrent = true
        return log
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
