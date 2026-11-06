import AppIntents
import Foundation

/// A bounded set of durations, so it can be embedded directly in a Siri
/// trigger phrase (App Intents only allows AppEntity/AppEnum there — a raw
/// Double can't go inline, which is what made "log 1 hour of sleep to
/// Dr Jay" fail to match before: the phrase had nowhere to put the "1 hour").
enum SleepDurationOption: String, AppEnum {
    case fifteenMinutes, thirtyMinutes, fortyFiveMinutes
    case oneHour, ninetyMinutes, twoHours, threeHours, fourHours
    case fiveHours, sixHours, sevenHours, eightHours, nineHours
    case tenHours, elevenHours, twelveHours

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sleep Duration"
    static let caseDisplayRepresentations: [SleepDurationOption: DisplayRepresentation] = [
        .fifteenMinutes: "15 minutes",
        .thirtyMinutes: "30 minutes",
        .fortyFiveMinutes: "45 minutes",
        .oneHour: "1 hour",
        .ninetyMinutes: "1.5 hours",
        .twoHours: "2 hours",
        .threeHours: "3 hours",
        .fourHours: "4 hours",
        .fiveHours: "5 hours",
        .sixHours: "6 hours",
        .sevenHours: "7 hours",
        .eightHours: "8 hours",
        .nineHours: "9 hours",
        .tenHours: "10 hours",
        .elevenHours: "11 hours",
        .twelveHours: "12 hours",
    ]

    var hours: Double {
        switch self {
        case .fifteenMinutes: 0.25
        case .thirtyMinutes: 0.5
        case .fortyFiveMinutes: 0.75
        case .oneHour: 1
        case .ninetyMinutes: 1.5
        case .twoHours: 2
        case .threeHours: 3
        case .fourHours: 4
        case .fiveHours: 5
        case .sixHours: 6
        case .sevenHours: 7
        case .eightHours: 8
        case .nineHours: 9
        case .tenHours: 10
        case .elevenHours: 11
        case .twelveHours: 12
        }
    }
}

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Bottle of Water"
    static let description = IntentDescription("Logs one finished bottle of water in Dr Jay.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let receipt = try await SiriWaterConfirmation.run(
            confirm: {
                try await requestConfirmation(
                    actionName: .continue,
                    dialog: "Log one bottle of WATER in Dr Jay? Cancel if you meant food."
                )
            },
            save: { try DayCoordinator.shared.logWithSiri(.water) }
        )
        return .result(dialog: IntentDialog(stringLiteral: receipt.dialog))
    }
}

/// Food has its own explicit route. Free-form food text is collected as a
/// parameter rather than interpolated into an AppShortcut trigger phrase.
struct LogFoodIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Food"
    static let description = IntentDescription("Logs what you ate in Dr Jay, without adding water or sleep.")
    // Foreground keeps the existing on-device food-assessment flow supported.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Food", requestValueDialog: "What did you eat?")
    var food: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log food: \(\.$food)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard SharedStore.loadSettings().onboardingComplete else {
            throw SiriLoggingError.onboardingRequired
        }
        let text = food.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FoodEntryPersistenceError.emptyDescription }
        guard let entry = await DayCoordinator.shared.logFood(text) else {
            throw FoodEntryPersistenceError.saveFailed
        }
        let dialog = entry.verdict == .unanalyzed
            ? "Food saved. This entry still needs review in History."
            : "Food saved. See Dr Jay for the assessment."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct ConfirmSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "Confirm Last Night's Sleep"
    static let description = IntentDescription("Tells Dr Jay whether you hit your sleep goal, without a specific number.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Got enough sleep?")
    var metGoal: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Confirm I got enough sleep: \(\.$metGoal)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let receipt = try DayCoordinator.shared.logWithSiri(.confirmSleep(met: metGoal))
        return .result(dialog: IntentDialog(stringLiteral: receipt.dialog))
    }
}

/// Voice-driven sleep logging — "log 1 hour of sleep to Dr Jay," etc.
/// `duration` is embedded directly in the trigger phrase (below), so Siri
/// matches the spoken amount against `SleepDurationOption`'s display names
/// in one shot — no follow-up question needed. Added to today's running
/// total (additive, exactly like tapping "Log Sleep" in the app).
struct LogSleepDurationIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Sleep Duration"
    static let description = IntentDescription("Adds a specific amount of sleep to today's total in Dr Jay.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Duration", requestValueDialog: "How long did you sleep?")
    var duration: SleepDurationOption

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$duration) of sleep")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let receipt = try DayCoordinator.shared.logWithSiri(.sleep(hours: duration.hours))
        return .result(dialog: IntentDialog(stringLiteral: receipt.dialog))
    }
}

struct HydrationStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Water Progress"
    static let description = IntentDescription("Reports today's water progress in Dr Jay.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: IntentDialog(stringLiteral: try DayCoordinator.shared.siriWaterStatus()))
    }
}

struct SleepStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Sleep Status"
    static let description = IntentDescription("Reports whether last night's sleep goal was met in Dr Jay.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: IntentDialog(stringLiteral: try DayCoordinator.shared.siriSleepStatus()))
    }
}

struct RoastieShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log a bottle in \(.applicationName)",
                "Log a bottle to \(.applicationName)",
                "Log water in \(.applicationName)",
                "Log water to \(.applicationName)",
                "Add a bottle in \(.applicationName)",
                "Add a bottle to \(.applicationName)",
                "Log a bottle of water in \(.applicationName)",
                "Log a bottle of water to \(.applicationName)",
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: LogFoodIntent(),
            phrases: [
                "Log food to \(.applicationName)",
                "Log food in \(.applicationName)",
                "Log my food to \(.applicationName)",
                "Log my meal in \(.applicationName)",
                "Add a meal to \(.applicationName)",
            ],
            shortTitle: "Log Food",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: LogSleepDurationIntent(),
            phrases: [
                "Log \(\.$duration) of sleep in \(.applicationName)",
                "Log \(\.$duration) of sleep to \(.applicationName)",
                "Log \(\.$duration) sleep to \(.applicationName)",
                // No embedded amount, in case Siri can't parse the spoken
                // duration against `SleepDurationOption`'s display strings —
                // the system falls back to `requestValueDialog` and asks
                // "How long did you sleep?" instead of failing to match.
                "Log sleep in \(.applicationName)",
                "Log sleep to \(.applicationName)",
                "Log my sleep in \(.applicationName)",
                "Log my sleep to \(.applicationName)",
            ],
            shortTitle: "Log Sleep Duration",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: HydrationStatusIntent(),
            phrases: [
                "How's my hydration in \(.applicationName)",
                "Check my water in \(.applicationName)",
            ],
            shortTitle: "Water Status",
            systemImageName: "drop.circle"
        )
        AppShortcut(
            intent: SleepStatusIntent(),
            phrases: [
                "Did I hit my sleep goal in \(.applicationName)",
                "Check my sleep in \(.applicationName)",
            ],
            shortTitle: "Sleep Status",
            systemImageName: "moon.zzz"
        )
        AppShortcut(
            intent: ConfirmSleepIntent(),
            phrases: [
                "Confirm my sleep in \(.applicationName)",
            ],
            shortTitle: "Confirm Sleep",
            systemImageName: "bed.double"
        )
    }
}

