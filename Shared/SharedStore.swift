import Foundation

/// Thin, dependency-free read/write layer over the App Group UserDefaults suite.
/// Used by the main app and widget/Live Activity extension so both agree on
/// "today" without needing SwiftData in the lightweight extension.
enum SharedStore {
    static func loadSettings() -> AppSettings {
        guard let data = AppConfig.sharedDefaults.data(forKey: AppConfig.DefaultsKey.settings) else {
            return AppSettings()
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            AppLogger.report(error, operation: "Decode settings", logger: AppLogger.sharedStore)
            return AppSettings()
        }
    }

    static func save(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            AppConfig.sharedDefaults.set(data, forKey: AppConfig.DefaultsKey.settings)
        } catch {
            AppLogger.report(error, operation: "Encode settings", logger: AppLogger.sharedStore)
        }
    }

    static func loadSnapshot() -> TodaySnapshot? {
        guard let data = AppConfig.sharedDefaults.data(forKey: AppConfig.DefaultsKey.snapshot) else {
            AppLogger.sharedStore.debug("No current snapshot is stored")
            return nil
        }
        do {
            return try JSONDecoder().decode(TodaySnapshot.self, from: data)
        } catch {
            AppLogger.report(error, operation: "Decode snapshot", logger: AppLogger.sharedStore)
            return nil
        }
    }

    static func save(_ snapshot: TodaySnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            AppConfig.sharedDefaults.set(data, forKey: AppConfig.DefaultsKey.snapshot)
        } catch {
            AppLogger.report(error, operation: "Encode snapshot", logger: AppLogger.sharedStore)
        }
    }
}
