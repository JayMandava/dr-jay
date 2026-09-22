import UIKit
import UserNotifications
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppConfig.recordInstallDateIfNeeded()
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.registerCategories()

        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppConfig.dailyRefreshTaskID, using: nil) { task in
            self.handleDailyRefresh(task: task as! BGProcessingTask)
        }

        return true
    }

    func scheduleDailyRefresh() {
        let request = BGProcessingTaskRequest(identifier: AppConfig.dailyRefreshTaskID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Calendar.current.date(bySettingHour: 5, minute: 0, second: 0, of: .now.addingTimeInterval(86400))
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleDailyRefresh(task: BGProcessingTask) {
        scheduleDailyRefresh() // chain the next one

        let refresh = Task {
            await DayCoordinator.shared.refreshToday()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            refresh.cancel()
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case AppConfig.NotificationAction.sleepYes:
            await DayCoordinator.shared.recordSleepSelfReport(met: true)
        case AppConfig.NotificationAction.sleepNo:
            await DayCoordinator.shared.recordSleepSelfReport(met: false)
        case AppConfig.NotificationAction.waterLog:
            await DayCoordinator.shared.logWaterBottle()
        case AppConfig.NotificationAction.waterLater, UNNotificationDismissActionIdentifier:
            break
        case UNNotificationDefaultActionIdentifier:
            await DayCoordinator.shared.refreshToday()
        default:
            break
        }
    }
}
