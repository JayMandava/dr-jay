import Foundation

enum AppConfig {
    static let appGroupID = "group.dev.jeyanth.roastie"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    enum NotificationCategory {
        static let sleepCheck = "SLEEP_CHECK"
        static let waterCheck = "WATER_CHECK"
    }

    enum NotificationAction {
        static let sleepYes = "SLEEP_YES"
        static let sleepNo = "SLEEP_NO"
        static let waterLog = "WATER_LOG"
        static let waterLater = "WATER_LATER"
    }

    enum UserInfoKey {
        static let kind = "kind"
        static let window = "window"
        static let destination = "destination"
    }

    enum NotificationDestination {
        static let dailyReport = "dailyReport"
    }

    enum DefaultsKey {
        static let snapshot = "today.snapshot"
        static let settings = "app.settings"
        static let appearance = "app.appearance"
        static let theme = "app.theme"
        static let foodCorrectionMemories = "food.correctionMemories"
        static let foodMemoryMigrationVersion = "food.memoryMigrationVersion"
        static let activityDayKey = "liveactivity.dayKey"
        static let installDate = "app.installDate"
        static let brainDumpModelProvider = "brainDump.modelProvider"
        static let brainDumpModelVerification = "brainDump.modelVerification"
        static let pendingDailyReportPresentation = "notification.pendingDailyReportPresentation"
    }

    static let dailyRefreshTaskID = "dev.jeyanth.roastie.dailyrefresh"

    static let sleepGoalHours: Double = 6.0
    /// Above this, you're oversleeping — that gets roasted too, same as undersleeping.
    static let sleepGoalMaxHours: Double = 9.0

    /// Records "now" as the install date on first call only; every later
    /// call is a no-op and returns the original date. Call this on every
    /// launch — it's cheap and idempotent.
    @discardableResult
    static func recordInstallDateIfNeeded() -> Date {
        if let existing = sharedDefaults.object(forKey: DefaultsKey.installDate) as? Date {
            return existing
        }
        let now = Date()
        sharedDefaults.set(now, forKey: DefaultsKey.installDate)
        return now
    }

    static var installDate: Date? {
        sharedDefaults.object(forKey: DefaultsKey.installDate) as? Date
    }

    static var provisioningExpiryDate: Date? {
        embeddedProvisioningExpiryDate
    }

    /// Only development-signed installs get a signing reminder. A missing
    /// profile (App Store/TestFlight) is never replaced with a guessed date.
    static func developmentExpiry(in profile: [String: Any]) -> Date? {
        guard let entitlements = profile["Entitlements"] as? [String: Any],
              entitlements["get-task-allow"] as? Bool == true else { return nil }
        return profile["ExpirationDate"] as? Date
    }

    /// Reads the real expiration date from the provisioning profile embedded
    /// in development builds. Re-signing the app replaces this profile, so the
    /// displayed deadline stays accurate even when app data is preserved.
    private static var embeddedProvisioningExpiryDate: Date? {
        guard
            let profileURL = Bundle.main.url(
                forResource: "embedded",
                withExtension: "mobileprovision"
            ),
            let profileData = try? Data(contentsOf: profileURL),
            let xmlStart = profileData.range(of: Data("<?xml".utf8)),
            let xmlEnd = profileData.range(
                of: Data("</plist>".utf8),
                in: xmlStart.lowerBound..<profileData.endIndex
            )
        else {
            return nil
        }

        let plistData = Data(profileData[xmlStart.lowerBound..<xmlEnd.upperBound])
        guard
            let profile = try? PropertyListSerialization.propertyList(
                from: plistData,
                format: nil
            ) as? [String: Any]
        else {
            return nil
        }

        return developmentExpiry(in: profile)
    }
}

extension Notification.Name {
    static let openDailyReportRequested = Notification.Name("openDailyReportRequested")
}

extension Date {
    /// Stable per-day key ("2026-09-21") used to key logs and detect day rollover.
    var dayKey: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
