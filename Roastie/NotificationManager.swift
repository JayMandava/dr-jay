import Foundation
import UserNotifications

/// Schedules a rolling week of six daily check-ins and exact-time
/// 10 p.m. summaries. Local notifications cannot be modified by a notification
/// service extension at delivery time, so each request is personalized from
/// the latest shared snapshot when it is scheduled. `DayCoordinator` calls
/// this again whenever that snapshot changes.
enum NotificationManager {

    @MainActor private static var isRescheduling = false
    @MainActor private static var pendingSettings: AppSettings?
    @MainActor private static var pendingSummary: DailySummaryInput?

    static func registerCategories() {
        let sleepYes = UNNotificationAction(identifier: AppConfig.NotificationAction.sleepYes, title: "Yes, within range", options: [])
        let sleepNo = UNNotificationAction(identifier: AppConfig.NotificationAction.sleepNo, title: "No", options: [])
        let sleepCategory = UNNotificationCategory(
            identifier: AppConfig.NotificationCategory.sleepCheck,
            actions: [sleepYes, sleepNo],
            intentIdentifiers: [],
            options: []
        )

        let waterLog = UNNotificationAction(identifier: AppConfig.NotificationAction.waterLog, title: "Log a bottle", options: [])
        let waterLater = UNNotificationAction(identifier: AppConfig.NotificationAction.waterLater, title: "Not yet", options: [])
        let waterCategory = UNNotificationCategory(
            identifier: AppConfig.NotificationCategory.waterCheck,
            actions: [waterLog, waterLater],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([sleepCategory, waterCategory])
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            AppLogger.report(error, operation: "Request notification authorization", logger: AppLogger.notifications)
            return false
        }
    }

    /// Cancels and reschedules all daily notifications, plus the backup-expiry
    /// reminder, against the current settings. Safe to call
    /// any time settings change — `removeAllPendingNotificationRequests`
    /// wipes everything first, so every scheduled thing has to be re-added
    /// here or it silently stops firing.
    @MainActor
    static func rescheduleAll(
        settings: AppSettings,
        dailySummaryInput: DailySummaryInput? = nil
    ) async {
        // Logging/Health updates can overlap at suspension points. Finish one
        // rebuild at a time, then apply the newest settings and snapshot last.
        pendingSettings = settings
        pendingSummary = dailySummaryInput
        guard !isRescheduling else { return }
        isRescheduling = true
        defer { isRescheduling = false }
        while let nextSettings = pendingSettings {
            let nextSummary = pendingSummary
            pendingSettings = nil
            pendingSummary = nil
            await rebuild(settings: nextSettings, dailySummaryInput: nextSummary)
        }
    }

    private static func rebuild(settings: AppSettings, dailySummaryInput: DailySummaryInput?) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let now = Date()
        let calendar = Calendar.current
        let snapshot = SharedStore.loadSnapshot().flatMap {
            $0.dayKey == now.dayKey ? $0 : nil
        }

        // 42 check-ins + 7 reports + 1 expiry reminder stay below iOS's
        // 64-request limit. Never repeat today's verdict on a future day.
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            for window in CheckInWindow.allCases {
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = settings.checkInHours[window] ?? window.defaultHour
                components.minute = 0
                guard let fireDate = calendar.date(from: components), fireDate > now else { continue }
                for kind in [CheckKind.sleep, .water] {
                    await schedule(
                        kind: kind,
                        window: window,
                        components: components,
                        dayKey: day.dayKey,
                        category: kind == .sleep ? AppConfig.NotificationCategory.sleepCheck : AppConfig.NotificationCategory.waterCheck,
                        settings: settings,
                        snapshot: dayOffset == 0 ? snapshot : nil
                    )
                }
            }
        }

        await scheduleDailySummaries(
            input: dailySummaryInput,
            settings: settings
        )
        await scheduleBackupReminder()
    }

    /// A personalized report is scheduled for today when it has not passed.
    /// Generic fallbacks cover the next six evenings if iOS does not relaunch
    /// the app; any foreground or Health update rebuilds the rolling schedule
    /// with fresh values. This avoids repeating yesterday's metrics forever.
    private static func scheduleDailySummaries(
        input: DailySummaryInput?,
        settings: AppSettings
    ) async {
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = 22
            components.minute = 0
            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Dr Jay’s daily report"
            if dayOffset == 0, let input {
                let report = DailySummaryCalculator.calculate(
                    input,
                    intensity: settings.roastIntensity,
                    profile: settings.dailyScoreProfile,
                    foodRoastsEnabled: settings.foodRoastsEnabled
                )
                content.body = "\(report.score)/100 · \(report.detail). \(report.roast)"
            } else {
                content.body = "Rounds are over. Open Dr Jay for today’s live report."
            }
            content.sound = .default
            content.interruptionLevel = .active
            content.userInfo = [
                AppConfig.UserInfoKey.destination: AppConfig.NotificationDestination.dailyReport,
            ]

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "daily.summary.\(day.dayKey)",
                content: content,
                trigger: trigger
            )
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                AppLogger.report(error, operation: "Schedule daily summary", logger: AppLogger.notifications)
            }
        }
    }

    /// Fires once, a day before an actual development signing profile expires.
    /// Distribution builds and missing profiles do not schedule this reminder.
    /// Harmless to call repeatedly — same identifier, same target date each
    /// time, and a past date is simply skipped.
    private static func scheduleBackupReminder() async {
        guard let expiry = AppConfig.provisioningExpiryDate else { return }
        guard let reminderDay = Calendar.current.date(byAdding: .day, value: -1, to: expiry) else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderDay)
        components.hour = 10
        components.minute = 0

        guard let fireDate = Calendar.current.date(from: components), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Backup reminder"
        content.body = "Your install expires tomorrow. Export a backup in Settings → Data so you don't lose your history."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "backup.expiry.reminder", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.report(error, operation: "Schedule backup reminder", logger: AppLogger.notifications)
        }
    }

    private static func schedule(
        kind: CheckKind,
        window: CheckInWindow,
        components: DateComponents,
        dayKey: String,
        category: String,
        settings: AppSettings,
        snapshot: TodaySnapshot?
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "\(window.label) check — \(kind == .sleep ? "Sleep" : "Water")"
        content.body = statusBody(kind: kind, window: window, settings: settings, snapshot: snapshot)
        content.categoryIdentifier = category
        content.userInfo = [
            AppConfig.UserInfoKey.kind: kind.rawValue,
            AppConfig.UserInfoKey.window: window.rawValue,
        ]
        content.interruptionLevel = .active
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "\(kind.rawValue).\(window.rawValue).\(dayKey)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.report(
                error,
                operation: "Schedule \(window.rawValue) \(kind.rawValue) notification",
                logger: AppLogger.notifications
            )
        }
    }

    static func statusBody(kind: CheckKind, window: CheckInWindow, settings: AppSettings, snapshot: TodaySnapshot?) -> String {
        guard let snapshot else {
            return kind == .sleep
                ? "Time for your sleep check. Open Dr Jay for today's status."
                : "Time for your water check. Open Dr Jay for today's status."
        }
        let detail: String
        let met: Bool
        let target: RoastTarget
        switch kind {
        case .sleep:
            guard let hours = snapshot.sleepHours else {
                return "No sleep logged yet. Open Dr Jay to check in."
            }
            detail = GoalCalculator.sleepDetail(hours: hours)
            met = GoalCalculator.sleepMet(hours: hours)
            target = hours > AppConfig.sleepGoalMaxHours ? .sleepOver : (met ? .sleepMet : .sleepUnder)
        case .water:
            detail = GoalCalculator.waterDetail(bottlesLogged: snapshot.waterBottlesLogged, goal: snapshot.waterGoalBottles)
            met = GoalCalculator.waterMet(bottlesLogged: snapshot.waterBottlesLogged, goal: snapshot.waterGoalBottles)
            target = met ? .waterMet : .waterIncomplete
        }
        // Alternate the approved punchlines across windows without model
        // latency or reusing a stale check-in's verdict/message.
        let first = RoastStyleContract.fallback(target: target, intensity: settings.roastIntensity)
        let roast = RoastStyleContract.fallback(
            target: target,
            intensity: settings.roastIntensity,
            excluding: window == .afternoon ? first : nil
        )
        return "\(capitalized(detail)) — \(met ? "Cleared." : "Flagged.") \(roast)"
    }

    private static func capitalized(_ value: String) -> String {
        value.prefix(1).uppercased() + value.dropFirst()
    }
}
