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
    private static let currentVersion = 4

    enum BackupError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                "This backup uses unsupported format version \(version)."
            }
        }
    }

    struct DailyLogExport: Codable, Equatable {
        var dayKey: String
        var date: Date
        var sleepHours: Double?
        var sleepSource: String
        var waterGoalBottles: Int
        var waterBottlesLogged: Int
        var waterTimestamps: [Date]
        var checkIns: [CheckInRecord]
        /// Optional keeps version-1 backups decodable; they simply contain no
        /// food history.
        var foodEntries: [FoodEntry]?
        var foodScore: Int?
        var foodScoreSummary: String?
        var foodScoreIsCurrent: Bool?
        var foodScoreVersion: Int?
    }

    struct BackupPayload: Codable, Equatable {
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
    static func write(_ logs: [DailyLog], to url: URL = fileURL) throws {
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
                    checkIns: $0.checkIns,
                    foodEntries: $0.foodEntries,
                    foodScore: $0.foodScore,
                    foodScoreSummary: $0.foodScoreSummary,
                    foodScoreIsCurrent: $0.foodScoreIsCurrent,
                    foodScoreVersion: $0.foodScoreVersion
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: url, options: .atomic)
    }

    static func read(from url: URL) throws -> BackupPayload {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)
        guard payload.version <= currentVersion else {
            throw BackupError.unsupportedVersion(payload.version)
        }
        return payload
    }

    static func restore(_ entry: DailyLogExport, into log: DailyLog) {
        log.date = entry.date
        log.sleepHours = entry.sleepHours
        log.sleepSource = entry.sleepSource
        log.waterGoalBottles = entry.waterGoalBottles
        log.waterBottlesLogged = entry.waterBottlesLogged
        log.waterTimestamps = entry.waterTimestamps
        log.checkIns = entry.checkIns
        log.foodEntries = entry.foodEntries ?? []
        log.foodScore = entry.foodScore
        log.foodScoreSummary = entry.foodScoreSummary
        log.foodScoreIsCurrent = entry.foodScoreIsCurrent ?? false
        log.foodScoreVersion = entry.foodScoreVersion
    }
}
