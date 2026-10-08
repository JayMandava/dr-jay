import AppIntents
import Foundation

/// LiveActivityIntent keeps mutations in the app process, which owns the
/// SwiftData context and updates the existing Live Activity. The UI stays closed.
struct AddHourSleepWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add 1h Sleep"
    static let description = IntentDescription("Adds one hour to today's sleep total in Dr Jay.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        #if ROASTIE_APP
        guard SharedStore.loadSettings().onboardingComplete else {
            throw QuickLogIntentError.onboardingRequired
        }
        await DayCoordinator.shared.logSleepHours(1, useOnDeviceModel: false)
        #else
        try QuickLogIntentError.requireAppProcess()
        #endif
        return .result()
    }
}

struct LogBottleWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log 1 Bottle"
    static let description = IntentDescription("Logs one finished bottle of water in Dr Jay.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        #if ROASTIE_APP
        guard SharedStore.loadSettings().onboardingComplete else {
            throw QuickLogIntentError.onboardingRequired
        }
        await DayCoordinator.shared.logWaterBottle(useOnDeviceModel: false)
        #else
        try QuickLogIntentError.requireAppProcess()
        #endif
        return .result()
    }
}

private enum QuickLogIntentError: LocalizedError {
    case onboardingRequired
    case appProcessRequired

    static func requireAppProcess() throws {
        throw Self.appProcessRequired
    }

    var errorDescription: String? {
        switch self {
        case .onboardingRequired: "Open Dr Jay and finish setup before using quick-log widgets."
        case .appProcessRequired: "Dr Jay couldn't run the logging action. Open the app once and try again."
        }
    }
}
