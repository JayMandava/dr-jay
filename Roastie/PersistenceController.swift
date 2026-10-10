import Foundation
import SwiftData

enum PersistenceController {
    static var storeURL: URL {
        (AppConfig.sharedContainerURL ?? URL.applicationSupportDirectory)
            .appending(path: "Roastie.sqlite")
    }

    /// SwiftData store lives inside the App Group container so a future
    /// widget/extension could read history directly if needed; today only
    /// the main app touches it, and lighter cross-process state travels
    /// through `SharedStore`/`TodaySnapshot` instead.
    static let modelContainer: ModelContainer = {
        let schema = Schema([DailyLog.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            excludeStoreFilesFromBackup()
            return container
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()

    /// iOS protects the App Group root. Only mark files owned by this app;
    /// metadata failure must never make an otherwise readable store unusable.
    static func backupFileURLs(for databaseURL: URL) -> [URL] {
        [databaseURL, URL(fileURLWithPath: databaseURL.path + "-wal"), URL(fileURLWithPath: databaseURL.path + "-shm")]
    }

    static func excludeStoreFilesFromBackup() {
        for var url in backupFileURLs(for: storeURL) where FileManager.default.fileExists(atPath: url.path) {
            do {
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try url.setResourceValues(values)
            } catch {
                AppLogger.report(error, operation: "Exclude database file from backup", logger: AppLogger.persistence)
            }
        }
    }
}
