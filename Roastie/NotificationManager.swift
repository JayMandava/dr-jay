import Foundation
import UserNotifications

/// Schedules the 6 repeating daily local notifications (sleep + water, x3
/// check-in windows). Local notifications cannot be modified by a notification
/// service extension at delivery time, so each request is personalized from
/// the latest shared snapshot when it is scheduled. `DayCoordinator` calls
/// this again whenever that snapshot changes.
enum NotificationManager {

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

    /// Cancels and reschedules all 6 repeating daily check-ins, plus the
    /// backup-expiry reminder, against the current settings. Safe to call
    /// any time settings change — `removeAllPendingNotificationRequests`
    /// wipes everything first, so every scheduled thing has to be re-added
    /// here or it silently stops firing.
    static func rescheduleAll(settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let snapshot = SharedStore.loadSnapshot().flatMap {
            $0.dayKey == Date().dayKey ? $0 : nil
        }

        for window in CheckInWindow.allCases {
            let hour = settings.checkInHours[window] ?? window.defaultHour
            await schedule(
                kind: .sleep,
                window: window,
                hour: hour,
                category: AppConfig.NotificationCategory.sleepCheck,
                settings: settings,
                snapshot: snapshot
            )
            await schedule(
                kind: .water,
                window: window,
                hour: hour,
                category: AppConfig.NotificationCategory.waterCheck,
                settings: settings,
                snapshot: snapshot
            )
        }

        await scheduleBackupReminder()
    }

    /// Fires once, a day before a free-provisioning install's 7-day trust
    /// window expires, nudging you to export a backup before it does.
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
        hour: Int,
        category: String,
        settings: AppSettings,
        snapshot: TodaySnapshot?
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "\(window.label) check — \(kind == .sleep ? "Sleep" : "Water")"
        content.body = statusBody(kind: kind, settings: settings, snapshot: snapshot)
        content.categoryIdentifier = category
        content.userInfo = [
            AppConfig.UserInfoKey.kind: kind.rawValue,
            AppConfig.UserInfoKey.window: window.rawValue,
        ]
        content.interruptionLevel = .active

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let identifier = "\(kind.rawValue).\(window.rawValue)"
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

    private static func statusBody(kind: CheckKind, settings: AppSettings, snapshot: TodaySnapshot?) -> String {
        switch kind {
        case .sleep:
            guard let hours = snapshot?.sleepHours else {
                return "No sleep data yet — Pending."
            }
            let detail = GoalCalculator.sleepDetail(hours: hours)
            return "\(capitalized(detail)) — \(GoalCalculator.sleepMet(hours: hours) ? "Cleared." : "Flagged.")"

        case .water:
            let bottlesLogged = snapshot?.waterBottlesLogged ?? 0
            let goal = snapshot?.waterGoalBottles ?? settings.waterGoalBottles
            let detail = GoalCalculator.waterDetail(bottlesLogged: bottlesLogged, goal: goal)
            return "\(capitalized(detail)) — \(GoalCalculator.waterMet(bottlesLogged: bottlesLogged, goal: goal) ? "Cleared." : "Flagged.")"
        }
    }

    private static func capitalized(_ value: String) -> String {
        value.prefix(1).uppercased() + value.dropFirst()
    }
}
