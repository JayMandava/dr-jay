import Foundation

struct StreakStats: Equatable {
    var current: Int
    var longest: Int
    var perfectDays: Int

    static let empty = StreakStats(current: 0, longest: 0, perfectDays: 0)
}

/// Derives streaks from `DailyLog`, which remains the only persisted source of
/// truth. Today is treated as pending until both goals are complete, so an
/// unfinished morning never hides the streak earned through yesterday.
enum StreakCalculator {
    static func calculate(
        logs: [DailyLog],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> StreakStats {
        let today = calendar.startOfDay(for: referenceDate)
        var completionByDay: [Date: Bool] = [:]

        for log in logs {
            let day = calendar.startOfDay(for: log.date)
            guard day <= today else { continue }
            completionByDay[day] = isPerfect(log)
        }

        guard !completionByDay.isEmpty else { return .empty }

        let sortedDays = completionByDay.keys.sorted()
        var longest = 0
        var running = 0
        var previousDay: Date?

        for day in sortedDays {
            let followsPrevious = previousDay.flatMap {
                calendar.date(byAdding: .day, value: 1, to: $0)
            } == day

            if completionByDay[day] == true {
                running = followsPrevious ? running + 1 : 1
                longest = max(longest, running)
            } else {
                running = 0
            }
            previousDay = day
        }

        let currentStart = completionByDay[today] == true
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)

        var current = 0
        var cursor = currentStart
        while let day = cursor, completionByDay[day] == true {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: day)
        }

        return StreakStats(
            current: current,
            longest: longest,
            perfectDays: completionByDay.values.filter { $0 }.count
        )
    }

    private static func isPerfect(_ log: DailyLog) -> Bool {
        log.sleepGoalMet == true && log.waterProgress >= 1
    }
}
