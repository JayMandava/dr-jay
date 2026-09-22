import Foundation

/// Thin, dependency-free read/write layer over the App Group UserDefaults suite.
/// Used by the main app, the widget/Live Activity extension, and the
/// notification service extension so all three agree on "today" without
/// needing SwiftData in the lightweight extensions.
enum SharedStore {
    static func loadSettings() -> AppSettings {
        guard let data = AppConfig.sharedDefaults.data(forKey: AppConfig.DefaultsKey.settings),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        AppConfig.sharedDefaults.set(data, forKey: AppConfig.DefaultsKey.settings)
    }

    static func loadSnapshot() -> TodaySnapshot? {
        guard let data = AppConfig.sharedDefaults.data(forKey: AppConfig.DefaultsKey.snapshot) else {
            print("[DrJay] loadSnapshot: no data under key '\(AppConfig.DefaultsKey.snapshot)' in suite '\(AppConfig.appGroupID)'")
            return nil
        }
        do {
            return try JSONDecoder().decode(TodaySnapshot.self, from: data)
        } catch {
            print("[DrJay] loadSnapshot: decode failed: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("[DrJay] loadSnapshot: raw JSON: \(raw)")
            }
            return nil
        }
    }

    static func save(_ snapshot: TodaySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppConfig.sharedDefaults.set(data, forKey: AppConfig.DefaultsKey.snapshot)
    }
}
