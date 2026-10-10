import Foundation
import SwiftData

enum PersistenceController {
    /// SwiftData store lives inside the App Group container so a future
    /// widget/extension could read history directly if needed; today only
    /// the main app touches it, and lighter cross-process state travels
    /// through `SharedStore`/`TodaySnapshot` instead.
    static let modelContainer: ModelContainer = {
        let schema = Schema([DailyLog.self])
        let storeURL = (AppConfig.sharedContainerURL ?? URL.applicationSupportDirectory)
            .appending(path: "Roastie.sqlite")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        do {
            // The App Group holds health records, WAL sidecars and shared
            // snapshots. Keep the entire private container out of cloud backup.
            var privateDirectory = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: privateDirectory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try privateDirectory.setResourceValues(values)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()
}
