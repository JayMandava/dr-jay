import Foundation

enum SleepStatus {
    case noData
    case under   // below the minimum
    case inRange // healthy window
    case over    // above the maximum — oversleeping
}

enum GoalCalculator {
    static func sleepStatus(hours: Double?) -> SleepStatus {
        guard let hours else { return .noData }
        if hours < AppConfig.sleepGoalHours { return .under }
        if hours > AppConfig.sleepGoalMaxHours { return .over }
        return .inRange
    }

    static func sleepMet(hours: Double?) -> Bool {
        sleepStatus(hours: hours) == .inRange
    }

    static func waterMet(bottlesLogged: Int, goal: Int) -> Bool {
        guard goal > 0 else { return true }
        return bottlesLogged >= goal
    }

    static func sleepDetail(hours: Double?) -> String {
        guard let hours else { return "no sleep data yet" }
        return "slept \(formatted(hours))h (target \(formatted(AppConfig.sleepGoalHours))–\(formatted(AppConfig.sleepGoalMaxHours))h)"
    }

    static func waterDetail(bottlesLogged: Int, goal: Int) -> String {
        "\(bottlesLogged) of \(goal) bottles logged"
    }

    private static func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
