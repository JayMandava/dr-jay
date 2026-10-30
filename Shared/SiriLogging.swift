import Foundation

/// Siri remains the voice entry point. Essential persistence does not depend on
/// optional model commentary, HealthKit reads, notifications or Live Activities.
enum SiriLogAction: Equatable {
    case water
    case sleep(hours: Double)
    case confirmSleep(met: Bool)
}

struct SiriLogReceipt: Equatable {
    let dialog: String
    let changed: Bool
}

enum SiriLoggingError: LocalizedError {
    case onboardingRequired
    case saveFailed
    case readFailed
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .onboardingRequired: "Open Dr Jay and finish setup before logging with Siri."
        case .saveFailed: "Your entry could not be saved. Open Dr Jay to check before trying again."
        case .readFailed: "Your saved data could not be read. Open Dr Jay and try again."
        case .invalidDuration: "Choose a sleep duration greater than zero and no more than 24 hours."
        }
    }
}

@MainActor
enum SiriLogging {
    /// One invocation performs one synchronous save. Do not retry automatically:
    /// AppIntent supplies no stable request ID to distinguish a retry from a
    /// deliberate second bottle/sleep entry. A time-window debounce would lose data.
    static func perform(
        _ action: SiriLogAction,
        log: DailyLog,
        onboardingComplete: Bool,
        now: Date = .now,
        window: CheckInWindow = .morning,
        save: () -> Bool
    ) throws -> SiriLogReceipt {
        guard onboardingComplete else { throw SiriLoggingError.onboardingRequired }
        let oldWater = log.waterBottlesLogged
        let oldTimestamps = log.waterTimestamps
        let oldSleep = log.sleepHours
        let oldSource = log.sleepSource
        let oldCheckIns = log.checkIns
        let kind: CheckKind
        let met: Bool
        let dialog: String

        switch action {
        case .water:
            guard log.waterBottlesLogged < Int.max else { throw SiriLoggingError.saveFailed }
            log.waterBottlesLogged += 1
            log.waterTimestamps.append(now)
            kind = .water
            met = GoalCalculator.waterMet(bottlesLogged: log.waterBottlesLogged, goal: log.waterGoalBottles)
            dialog = "Bottle saved. \(log.waterBottlesLogged) of \(log.waterGoalBottles) bottles today."
        case .sleep(let hours):
            guard hours.isFinite, hours > 0, hours <= 24 else { throw SiriLoggingError.invalidDuration }
            let total = (log.sleepHours ?? 0) + hours
            guard total.isFinite else { throw SiriLoggingError.invalidDuration }
            log.sleepHours = total
            log.sleepSource = "manual"
            kind = .sleep
            met = GoalCalculator.sleepMet(hours: log.sleepHours)
            dialog = "Sleep saved. \(format(log.sleepHours ?? 0)) hours total today."
        case .confirmSleep(let goalMet):
            // Preserve Health as the source of truth, but do not claim the user's
            // conflicting yes/no response changed the stored value.
            if log.sleepSource == "healthkit" {
                let detail = log.sleepHours.map {
                    "Health records \(format($0)) hours; sleep goal \(GoalCalculator.sleepMet(hours: $0) ? "met" : "not met")."
                } ?? "Sleep is managed by Health, but no hours are available."
                return SiriLogReceipt(dialog: "\(detail) No changes made. Use Dr Jay to replace Health data manually.", changed: false)
            }
            log.sleepHours = goalMet ? AppConfig.sleepGoalHours : max(0, AppConfig.sleepGoalHours - 2)
            log.sleepSource = "manual"
            kind = .sleep
            met = GoalCalculator.sleepMet(hours: log.sleepHours)
            dialog = "Sleep goal self-report saved as an estimate of \(format(log.sleepHours ?? 0)) hours. Use Log Sleep for an exact duration."
        }

        log.checkIns.append(CheckInRecord(
            window: window, kind: kind, timestamp: now, met: met,
            message: dialog, wasGeneratedByModel: false
        ))
        guard save() else {
            log.waterBottlesLogged = oldWater
            log.waterTimestamps = oldTimestamps
            log.sleepHours = oldSleep
            log.sleepSource = oldSource
            log.checkIns = oldCheckIns
            throw SiriLoggingError.saveFailed
        }
        return SiriLogReceipt(dialog: dialog, changed: true)
    }

    static func waterStatus(log: DailyLog?, now: Date = .now) -> String {
        guard let log, log.dayKey == now.dayKey else {
            return "No water data yet today — log a bottle to get started."
        }
        return "You're at \(log.waterBottlesLogged) of \(log.waterGoalBottles) bottles today."
    }

    static func sleepStatus(log: DailyLog?, now: Date = .now) -> String {
        guard let log, log.dayKey == now.dayKey, let hours = log.sleepHours else {
            return "No sleep data yet today."
        }
        return "You slept \(format(hours)) hours — goal \(GoalCalculator.sleepMet(hours: hours) ? "met" : "missed")."
    }

    private static func format(_ value: Double) -> String {
        let precise = String(format: "%.2f", value)
        return precise.hasSuffix("0") ? String(precise.dropLast()) : precise
    }
}
