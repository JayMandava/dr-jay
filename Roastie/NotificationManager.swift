import Foundation
import UserNotifications

/// Schedules the 6 repeating daily local notifications (sleep + water, x3
/// check-in windows). Content is intentionally generic here — the
/// notification service extension personalizes title/body with a
/// freshly-generated roast/hype line right at delivery time, using whatever
/// is logged by then.
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
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Cancels and reschedules all 6 repeating daily check-ins, plus the
    /// backup-expiry reminder, against the current settings. Safe to call
    /// any time settings change — `removeAllPendingNotificationRequests`
    /// wipes everything first, so every scheduled thing has to be re-added
    /// here or it silently stops firing.
    static func rescheduleAll(settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for window in CheckInWindow.allCases {
            let hour = settings.checkInHours[window] ?? window.defaultHour
            await schedule(kind: .sleep, window: window, hour: hour, category: AppConfig.NotificationCategory.sleepCheck, title: "Sleep check-in", body: "Checking in on last night…")
            await schedule(kind: .water, window: window, hour: hour, category: AppConfig.NotificationCategory.waterCheck, title: "Hydration check-in", body: "Checking your water pace…")
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
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func schedule(kind: CheckKind, window: CheckInWindow, hour: Int, category: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
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
        try? await UNUserNotificationCenter.current().add(request)
    }
}
