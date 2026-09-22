import UserNotifications

/// Runs entirely on-device, right as the notification is about to be shown.
/// Reads the freshest logged data from the App Group store and fills in
/// today's plain status/progress — so what you see reflects what you'd
/// logged by delivery time, not whatever was known when the notification was
/// scheduled. Deliberately no AI-generated roast here: the full line lives in
/// the app itself, where there's room for it — a notification banner is a
/// glance, not a diagnosis.
@MainActor
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestEffortContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        self.bestEffortContent = mutableContent

        guard
            let kindRaw = mutableContent.userInfo[AppConfig.UserInfoKey.kind] as? String,
            let kind = CheckKind(rawValue: kindRaw),
            let windowRaw = mutableContent.userInfo[AppConfig.UserInfoKey.window] as? String,
            let window = CheckInWindow(rawValue: windowRaw)
        else {
            contentHandler(mutableContent)
            return
        }

        Task { @MainActor in
            let settings = SharedStore.loadSettings()
            let snapshot = SharedStore.loadSnapshot()

            let met: Bool
            let detail: String
            switch kind {
            case .sleep:
                met = GoalCalculator.sleepMet(hours: snapshot?.sleepHours)
                detail = GoalCalculator.sleepDetail(hours: snapshot?.sleepHours)
            case .water:
                let goalBottles = snapshot?.waterGoalBottles ?? settings.waterGoalBottles
                met = GoalCalculator.waterMet(bottlesLogged: snapshot?.waterBottlesLogged ?? 0, goal: goalBottles)
                detail = GoalCalculator.waterDetail(bottlesLogged: snapshot?.waterBottlesLogged ?? 0, goal: goalBottles)
            }

            let capitalizedDetail = detail.prefix(1).uppercased() + detail.dropFirst()
            mutableContent.title = "\(window.label) check — \(kind == .sleep ? "Sleep" : "Water")"
            mutableContent.body = "\(capitalizedDetail) — \(met ? "Cleared." : "Flagged.")"
            mutableContent.sound = .default

            deliver(mutableContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let bestEffortContent {
            deliver(bestEffortContent)
        }
    }

    private func deliver(_ content: UNMutableNotificationContent) {
        contentHandler?(content)
        contentHandler = nil
    }
}
