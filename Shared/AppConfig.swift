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
    }

    enum DefaultsKey {
        static let snapshot = "today.snapshot"
        static let settings = "app.settings"
        static let foodCorrectionMemories = "food.correctionMemories"
        static let foodMemoryMigrationVersion = "food.memoryMigrationVersion"
        static let activityDayKey = "liveactivity.dayKey"
        static let installDate = "app.installDate"
    }

    static let dailyRefreshTaskID = "dev.jeyanth.roastie.dailyrefresh"

    static let sleepGoalHours: Double = 6.0
    /// Above this, you're oversleeping — that gets roasted too, same as undersleeping.
    static let sleepGoalMaxHours: Double = 9.0

    /// A free (non-paid) developer install stops trusting its signature 7
    /// days after install — this is that window, used to time the backup
    /// reminder a day before it expires.
    static let freeProvisioningWindowDays = 7

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
        guard let installDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: freeProvisioningWindowDays, to: installDate)
    }
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
