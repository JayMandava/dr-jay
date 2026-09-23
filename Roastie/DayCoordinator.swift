import Foundation
import SwiftData
import ActivityKit
import UserNotifications
import WidgetKit

/// Central orchestrator: owns "what day is it, what's logged, what does the
/// Live Activity/widget/notification content say right now." Called from
/// app launch, scene-phase changes, manual logging actions, notification
/// actions, and the daily background refresh task.
@MainActor
final class DayCoordinator {
    static let shared = DayCoordinator()

    private let context: ModelContext

    private init() {
        self.context = ModelContext(PersistenceController.modelContainer)
    }

    private func saveContext(operation: String) {
        do {
            try context.save()
        } catch {
            AppLogger.report(error, operation: operation, logger: AppLogger.persistence)
        }
    }

    // MARK: - Today

    @discardableResult
    func todayLog() -> DailyLog {
        let key = Date().dayKey
        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dayKey == key })
        do {
            if let existing = try context.fetch(descriptor).first {
                return existing
            }
        } catch {
            AppLogger.report(error, operation: "Fetch today's log", logger: AppLogger.persistence)
        }
        let settings = SharedStore.loadSettings()
        let log = DailyLog(dayKey: key, date: Date().startOfDay, waterGoalBottles: settings.waterGoalBottles)
        context.insert(log)
        saveContext(operation: "Create today's log")
        return log
    }

    /// Settings only writes the new goal into `AppSettings` — today's
    /// `DailyLog` was already stamped with whatever goal was active when it
    /// was first created, and every "today" surface (widgets, Live Activity,
    /// TodayView, notifications) reads that stamped value, not the settings
    /// one. Without this, changing the goal in Settings silently didn't show
    /// up anywhere until the next day's log was created from scratch.
    func applyWaterGoalChange(_ goal: Int) async {
        let log = todayLog()
        guard log.waterGoalBottles != goal else { return }
        log.waterGoalBottles = goal
        saveContext(operation: "Save water goal change")

        let settings = SharedStore.loadSettings()
        await pushSnapshot(log: log, settings: settings)
        await syncLiveActivity(log: log)
        persistBackup()
    }

    /// Call on launch, foreground, and daily background refresh: pulls fresh
    /// sleep from HealthKit (if enabled), recomputes the snapshot, and syncs
    /// the Live Activity.
    func refreshToday() async {
        let log = todayLog()
        let settings = SharedStore.loadSettings()

        // Reconciles today's already-created log against the current
        // settings goal, in case it changed after today's log was stamped
        // (see `applyWaterGoalChange`) — self-healing on every refresh so a
        // goal change always shows up, even without revisiting Settings.
        if log.waterGoalBottles != settings.waterGoalBottles {
            log.waterGoalBottles = settings.waterGoalBottles
            saveContext(operation: "Reconcile today's water goal")
        }

        // A manual entry is an explicit choice for today's total. Once made,
        // foreground refreshes leave it alone unless the user explicitly
        // chooses "Replace with Health Data" from the sleep sheet.
        if settings.healthKitEnabled,
           HealthKitManager.shared.isAvailable,
           log.sleepSource != "manual" {
            do {
                if let hours = try await HealthKitManager.shared.sleepHoursLastNight() {
                    log.sleepHours = hours
                    log.sleepSource = "healthkit"
                    saveContext(operation: "Save Health sleep data")
                }
            } catch {
                AppLogger.report(error, operation: "Read Health sleep data", logger: AppLogger.health)
            }
        }

        await pushSnapshot(log: log, settings: settings)
        await syncLiveActivity(log: log)
        persistBackup()
    }

    // MARK: - Logging

    func logWaterBottle() async {
        let log = todayLog()
        log.waterBottlesLogged += 1
        log.waterTimestamps.append(.now)
        saveContext(operation: "Log water bottle")

        let settings = SharedStore.loadSettings()
        let window = currentWindow(settings: settings)
        let met = GoalCalculator.waterMet(bottlesLogged: log.waterBottlesLogged, goal: log.waterGoalBottles)
        _ = await generateAndRecord(kind: .water, window: window, met: met, log: log, settings: settings)

        await pushSnapshot(log: log, settings: settings)
        await syncLiveActivity(log: log)
        persistBackup()
    }

    /// Free-form manual sleep entry — logged any time, same as water, not
    /// gated to a check-in window. Additive, like water: each call adds to
    /// today's running total and makes manual data authoritative for the rest
    /// of the day.
    func logSleepHours(_ additionalHours: Double) async {
        let log = todayLog()
        let total = (log.sleepHours ?? 0) + additionalHours
        log.sleepHours = total
        log.sleepSource = "manual"
        saveContext(operation: "Log manual sleep")

        let settings = SharedStore.loadSettings()
        let window = currentWindow(settings: settings)
        let met = GoalCalculator.sleepMet(hours: total)
        _ = await generateAndRecord(kind: .sleep, window: window, met: met, log: log, settings: settings)

        await pushSnapshot(log: log, settings: settings)
        await syncLiveActivity(log: log)
        persistBackup()
    }

    /// Explicitly discards today's manual total in favor of the latest
    /// HealthKit value. Returns false when HealthKit has no sleep data to use.
    @discardableResult
    func replaceSleepWithHealthData() async -> Bool {
        guard HealthKitManager.shared.isAvailable else { return false }

        let hours: Double
        do {
            guard let healthHours = try await HealthKitManager.shared.sleepHoursLastNight() else {
                return false
            }
            hours = healthHours
        } catch {
            AppLogger.report(error, operation: "Replace sleep with Health data", logger: AppLogger.health)
            return false
        }

        let log = todayLog()
        log.sleepHours = hours
        log.sleepSource = "healthkit"
        saveContext(operation: "Replace sleep with Health data")

        let settings = SharedStore.loadSettings()
        await pushSnapshot(log: log, settings: settings)
        await syncLiveActivity(log: log)
        persistBackup()
        return true
    }

    /// Quick Yes/No from a notification action — coarser than `logSleepHours`
    /// but still useful for a fast reply without opening the app.
    func recordSleepSelfReport(met: Bool) async {
        let log = todayLog()
        if log.sleepSource != "healthkit" {
            log.sleepHours = met ? AppConfig.sleepGoalHours : max(0, AppConfig.sleepGoalHours - 2)
            log.sleepSource = "manual"
            saveContext(operation: "Save sleep self-report")
        }

        let settings = SharedStore.loadSettings()
        let window = currentWindow(settings: settings)
        _ = await generateAndRecord(kind: .sleep, window: window, met: met, log: log, settings: settings)

        await pushSnapshot(log: log, settings: settings)
        await syncLiveActivity(log: log)
        persistBackup()
    }

    private func generateAndRecord(kind: CheckKind, window: CheckInWindow, met: Bool, log: DailyLog, settings: AppSettings) async -> NudgeMessage {
        let detail = kind == .sleep
            ? GoalCalculator.sleepDetail(hours: log.sleepHours)
            : GoalCalculator.waterDetail(bottlesLogged: log.waterBottlesLogged, goal: log.waterGoalBottles)
        let value = kind == .sleep ? (log.sleepHours ?? 0) : Double(log.waterBottlesLogged)
        let goal = kind == .sleep ? AppConfig.sleepGoalHours : Double(log.waterGoalBottles)

        let context = NudgeContext(kind: kind, window: window, met: met, detail: detail, value: value, goal: goal, streak: streak(), intensity: settings.roastIntensity)
        let message = await RoastEngine.generate(context)

        log.checkIns.append(CheckInRecord(
            window: window, kind: kind, timestamp: .now, met: met,
            message: message.text, wasGeneratedByModel: true
        ))
        saveContext(operation: "Save check-in message")
        return message
    }

    // MARK: - Streak

    func streak() -> Int {
        do {
            return StreakCalculator.calculate(
                logs: try context.fetch(FetchDescriptor<DailyLog>())
            ).current
        } catch {
            AppLogger.report(error, operation: "Calculate streak", logger: AppLogger.persistence)
            return 0
        }
    }

    // MARK: - Reset

    /// Wipes every trace of local app state: all history, the shared
    /// snapshot, settings, pending notifications, and any running Live
    /// Activity. Used by the "Reset App Data" action in Settings.
    func resetAllData() async {
        do {
            let logs = try context.fetch(FetchDescriptor<DailyLog>())
            for log in logs { context.delete(log) }
            try context.save()
        } catch {
            AppLogger.report(error, operation: "Reset stored logs", logger: AppLogger.persistence)
        }

        AppConfig.sharedDefaults.removeObject(forKey: AppConfig.DefaultsKey.snapshot)
        AppConfig.sharedDefaults.removeObject(forKey: AppConfig.DefaultsKey.settings)
        AppConfig.sharedDefaults.removeObject(forKey: AppConfig.DefaultsKey.activityDayKey)

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        for activity in Activity<RoastieActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        do {
            try FileManager.default.removeItem(at: BackupManager.fileURL)
        } catch {
            if (error as NSError).code != NSFileNoSuchFileError {
                AppLogger.report(error, operation: "Remove backup during reset", logger: AppLogger.backup)
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Backup / restore

    /// Rewrites the on-disk JSON backup from the current SwiftData state.
    /// Called after every mutation so the file is never more than one write
    /// stale — this is what "Export" in Settings shares, and what a future
    /// reinstall's "Import" restores from.
    func writeBackupNow() throws {
        let logs = try context.fetch(FetchDescriptor<DailyLog>())
        try BackupManager.write(logs)
    }

    private func persistBackup() {
        do {
            try writeBackupNow()
        } catch {
            AppLogger.report(error, operation: "Persist automatic backup", logger: AppLogger.backup)
        }
    }

    /// Merges a backup payload into the current store: each imported day
    /// overwrites the matching local day (by `dayKey`) if one exists, or is
    /// inserted fresh otherwise. Existing days not present in the backup are
    /// left untouched.
    @discardableResult
    func importBackup(from url: URL) async throws -> Int {
        let payload = try BackupManager.read(from: url)

        for entry in payload.logs {
            let key = entry.dayKey
            let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dayKey == key })
            let log = try context.fetch(descriptor).first ?? {
                let new = DailyLog(dayKey: entry.dayKey, date: entry.date, waterGoalBottles: entry.waterGoalBottles)
                context.insert(new)
                return new
            }()

            BackupManager.restore(entry, into: log)
        }

        try context.save()
        await refreshToday()
        return payload.logs.count
    }

    // MARK: - Snapshot / Live Activity plumbing

    private func currentWindow(settings: AppSettings) -> CheckInWindow {
        CheckInWindowResolver.closest(to: .now, settings: settings)
    }

    /// Sleep/water messages are derived straight from today's `checkIns` —
    /// the real, persisted source of truth — rather than round-tripped
    /// through the cached JSON snapshot. That cache is only a read-optimized
    /// mirror for the widget/Live Activity processes; deriving from it was
    /// what let a schema change (or any decode hiccup) silently wipe a
    /// perfectly good message even though the underlying log data was fine.
    ///
    /// The Cleared/Flagged status, though, is recomputed live from
    /// `GoalCalculator` every time — not read off the last check-in's `met`
    /// flag. A check-in's `met` is frozen at the moment it was recorded, so
    /// it goes stale the instant the rule or the goal changes (exactly what
    /// happened when water switched from pace-based to full-goal-based:
    /// every already-logged check-in still said "met" under the old rule).
    /// Status badges should always reflect "given today's numbers and
    /// today's rule, right now" — never a frozen historical verdict.
    private func pushSnapshot(log: DailyLog, settings: AppSettings) async {
        let latestSleepCheckIn = log.checkIns.filter { $0.kind == .sleep }.max { $0.timestamp < $1.timestamp }
        let latestWaterCheckIn = log.checkIns.filter { $0.kind == .water }.max { $0.timestamp < $1.timestamp }

        let sleepMessage = latestSleepCheckIn?.message
            ?? log.sleepHours.map { "\(String(format: "%.1f", $0))h logged." }
            ?? "No sleep logged yet."
        let waterMessage = latestWaterCheckIn?.message
            ?? (log.waterBottlesLogged > 0 ? "\(log.waterBottlesLogged) of \(log.waterGoalBottles) bottles logged." : "No water logged yet.")

        let snapshot = TodaySnapshot(
            dayKey: log.dayKey,
            sleepHours: log.sleepHours,
            sleepGoalMet: log.sleepGoalMet,
            waterBottlesLogged: log.waterBottlesLogged,
            waterGoalBottles: log.waterGoalBottles,
            streak: streak(),
            sleepMessage: sleepMessage,
            sleepWasRoast: !GoalCalculator.sleepMet(hours: log.sleepHours),
            waterMessage: waterMessage,
            waterWasRoast: !GoalCalculator.waterMet(bottlesLogged: log.waterBottlesLogged, goal: log.waterGoalBottles),
            updatedAt: .now
        )
        SharedStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        await NotificationManager.rescheduleAll(settings: settings)
    }

    private func nextCheckInLabel(settings: AppSettings) -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        let upcoming = CheckInWindow.allCases.first { (settings.checkInHours[$0] ?? $0.defaultHour) > hour }
        return upcoming?.label ?? "Tomorrow morning"
    }

    private func syncLiveActivity(log: DailyLog) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let settings = SharedStore.loadSettings()
        guard let snapshot = SharedStore.loadSnapshot() else { return }

        let state = RoastieActivityAttributes.ContentState(
            snapshot: snapshot,
            nextCheckInLabel: nextCheckInLabel(settings: settings)
        )
        let content = ActivityContent(state: state, staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: .now))

        await Self.applyLiveActivity(dayKey: log.dayKey, content: content)
    }

    /// Isolated away from the MainActor deliberately: `Activity.update`/`.end`
    /// run on their own concurrent executor, and keeping this call nonisolated
    /// avoids "sending main-actor-isolated value" races under strict concurrency.
    private nonisolated static func applyLiveActivity(dayKey: String, content: ActivityContent<RoastieActivityAttributes.ContentState>) async {
        if let activity = Activity<RoastieActivityAttributes>.activities.first(where: { $0.attributes.startedDayKey == dayKey }) {
            await activity.update(content)
            return
        }

        // A stale activity from a previous day, if any, should be ended.
        for activity in Activity<RoastieActivityAttributes>.activities {
            await activity.end(content, dismissalPolicy: .immediate)
        }

        do {
            _ = try Activity<RoastieActivityAttributes>.request(
                attributes: RoastieActivityAttributes(startedDayKey: dayKey),
                content: content,
                pushType: nil
            )
        } catch {
            AppLogger.report(error, operation: "Start Live Activity", logger: AppLogger.activity)
        }
    }
}
