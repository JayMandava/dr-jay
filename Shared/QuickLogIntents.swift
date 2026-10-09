import AppIntents
import Foundation
import WidgetKit

/// UI-only receipts, separate from health records and JSON backups.
enum QuickLogReceipt {
    static func date(for kind: CheckKind) -> Date? {
        AppConfig.sharedDefaults.object(forKey: key(for: kind)) as? Date
    }

    static func record(_ kind: CheckKind, saved: Bool) {
        if saved {
            AppConfig.sharedDefaults.set(Date(), forKey: key(for: kind))
        } else {
            AppConfig.sharedDefaults.removeObject(forKey: key(for: kind))
        }
        WidgetCenter.shared.reloadTimelines(ofKind: kind == .sleep ? "AddHourSleepWidget" : "LogBottleWidget")
    }

    private static func key(for kind: CheckKind) -> String {
        "widget.quickLog.\(kind.rawValue).lastSaved"
    }
}

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
        let saved = await DayCoordinator.shared.logSleepHours(1, useOnDeviceModel: false)
        QuickLogReceipt.record(.sleep, saved: saved)
        guard saved else { throw QuickLogIntentError.saveFailed }
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
        let saved = await DayCoordinator.shared.logWaterBottle(useOnDeviceModel: false)
        QuickLogReceipt.record(.water, saved: saved)
        guard saved else { throw QuickLogIntentError.saveFailed }
        #else
        try QuickLogIntentError.requireAppProcess()
        #endif
        return .result()
    }
}

private enum QuickLogIntentError: LocalizedError {
    case onboardingRequired
    case appProcessRequired
    case saveFailed

    static func requireAppProcess() throws {
        throw Self.appProcessRequired
    }

    var errorDescription: String? {
        switch self {
        case .onboardingRequired: "Open Dr Jay and finish setup before using quick-log widgets."
        case .appProcessRequired: "Dr Jay couldn't run the logging action. Open the app once and try again."
        case .saveFailed: "Your entry couldn't be saved. Open Dr Jay and try again."
        }
    }
}
