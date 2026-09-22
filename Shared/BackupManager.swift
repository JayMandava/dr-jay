import Foundation

/// A portable, human-readable JSON backup of every logged day — rewritten
/// automatically in the background on every log/check-in so it's never stale.
/// This is the safety net for a free-provisioning install expiring after 7
/// days: export it (Settings → share sheet) before that happens, then import
/// it back in after reinstalling to restore history instead of losing it.
/// Reinstalling from Xcode with the same bundle ID normally preserves app
/// data on its own — this exists for the cases that doesn't cover: a clean
/// reinstall, a new device, or just wanting your history in a plain file.
enum BackupManager {
    private static let fileName = "dr-jay-backup.json"
    private static let currentVersion = 1

    struct DailyLogExport: Codable {
        var dayKey: String
        var date: Date
        var sleepHours: Double?
        var sleepSource: String
        var waterGoalBottles: Int
        var waterBottlesLogged: Int
        var waterTimestamps: [Date]
        var checkIns: [CheckInRecord]
    }

    struct BackupPayload: Codable {
        var version: Int
        var exportedAt: Date
        var logs: [DailyLogExport]
    }

    static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: fileName)
    }

    /// Rewrites the backup file from the current set of logs. Cheap enough
    /// for a personal app's data volume to just do a full rewrite each time.
    static func write(_ logs: [DailyLog]) {
        let payload = BackupPayload(
            version: currentVersion,
            exportedAt: .now,
            logs: logs.map {
                DailyLogExport(
                    dayKey: $0.dayKey,
                    date: $0.date,
                    sleepHours: $0.sleepHours,
                    sleepSource: $0.sleepSource,
                    waterGoalBottles: $0.waterGoalBottles,
                    waterBottlesLogged: $0.waterBottlesLogged,
                    waterTimestamps: $0.waterTimestamps,
                    checkIns: $0.checkIns
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func read(from url: URL) throws -> BackupPayload {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupPayload.self, from: data)
    }
}
