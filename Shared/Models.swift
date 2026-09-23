import Foundation
import SwiftData

enum CheckInWindow: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning, afternoon, night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .night: "Night"
        }
    }

    var defaultHour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 14
        case .night: 21
        }
    }
}

enum CheckKind: String, Codable, Sendable {
    case sleep, water
}

enum RoastIntensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case gentle, playful, spicy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: "Gentle"
        case .playful: "Playful"
        case .spicy: "Spicy"
        }
    }
}

struct CheckInRecord: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var window: CheckInWindow
    var kind: CheckKind
    var timestamp: Date
    var met: Bool
    var message: String
    var wasGeneratedByModel: Bool
}

enum FoodVerdict: String, Codable, Hashable, Sendable {
    case healthy
    case unhealthy
    case unanalyzed

    var label: String {
        switch self {
        case .healthy: "Healthy"
        case .unhealthy: "Unhealthy"
        case .unanalyzed: "Couldn’t analyse"
        }
    }
}

struct FoodEntry: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var text: String
    var timestamp: Date
    var verdict: FoodVerdict
    var assessment: String?
    var roast: String?
}

enum FoodScoreBand: String, Codable, Equatable, Sendable {
    case good = "Good"
    case bad = "Bad"
    case ugly = "Ugly"

    static func classify(_ score: Int) -> FoodScoreBand {
        switch score {
        case 80...: .good
        case 60...: .bad
        default: .ugly
        }
    }
}

/// One row per calendar day. Source of truth for history/streaks; lives only
/// in the main app's SwiftData store (widgets/extension read `TodaySnapshot` instead).
@Model
final class DailyLog {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var sleepHours: Double?
    var sleepSource: String // "healthkit" | "manual" | "unknown"
    var waterGoalBottles: Int
    var waterBottlesLogged: Int
    var waterTimestamps: [Date]
    var checkIns: [CheckInRecord]
    /// Optional so existing SwiftData stores migrate without needing a value
    /// synthesized for rows written before food tracking existed.
    var foodEntries: [FoodEntry]?
    /// Optional fields keep stores created before food scoring migratable.
    var foodScore: Int?
    var foodScoreSummary: String?
    var foodScoreIsCurrent: Bool?

    init(dayKey: String, date: Date, waterGoalBottles: Int) {
        self.dayKey = dayKey
        self.date = date
        self.sleepHours = nil
        self.sleepSource = "unknown"
        self.waterGoalBottles = waterGoalBottles
        self.waterBottlesLogged = 0
        self.waterTimestamps = []
        self.checkIns = []
        self.foodEntries = []
        self.foodScore = nil
        self.foodScoreSummary = nil
        self.foodScoreIsCurrent = true
    }

    var sleepGoalMet: Bool? {
        guard sleepHours != nil else { return nil }
        return GoalCalculator.sleepMet(hours: sleepHours)
    }

    var waterProgress: Double {
        guard waterGoalBottles > 0 else { return 0 }
        return min(1, Double(waterBottlesLogged) / Double(waterGoalBottles))
    }

    var sleepProgress: Double {
        min(1, (sleepHours ?? 0) / AppConfig.sleepGoalHours)
    }
}

/// Cheap cross-process snapshot of "today" — written by the app/coordinator,
/// read by widgets, the Live Activity, App Intents, and notification scheduling.
///
/// Sleep and water each keep their own latest message/verdict, so logging one
/// never overwrites the other's status — both stay visible everywhere
/// (Dynamic Island, widgets, Lock Screen) instead of only whichever was
/// logged most recently.
struct TodaySnapshot: Codable, Sendable {
    var dayKey: String
    var sleepHours: Double?
    var sleepGoalMet: Bool?
    var waterBottlesLogged: Int
    var waterGoalBottles: Int
    var streak: Int
    var sleepMessage: String
    var sleepWasRoast: Bool
    var waterMessage: String
    var waterWasRoast: Bool
    var updatedAt: Date

    var waterProgress: Double {
        guard waterGoalBottles > 0 else { return 0 }
        return min(1, Double(waterBottlesLogged) / Double(waterGoalBottles))
    }

    var sleepProgress: Double {
        min(1, (sleepHours ?? 0) / AppConfig.sleepGoalHours)
    }

    init(dayKey: String, sleepHours: Double?, sleepGoalMet: Bool?, waterBottlesLogged: Int, waterGoalBottles: Int, streak: Int, sleepMessage: String, sleepWasRoast: Bool, waterMessage: String, waterWasRoast: Bool, updatedAt: Date) {
        self.dayKey = dayKey
        self.sleepHours = sleepHours
        self.sleepGoalMet = sleepGoalMet
        self.waterBottlesLogged = waterBottlesLogged
        self.waterGoalBottles = waterGoalBottles
        self.streak = streak
        self.sleepMessage = sleepMessage
        self.sleepWasRoast = sleepWasRoast
        self.waterMessage = waterMessage
        self.waterWasRoast = waterWasRoast
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case dayKey, sleepHours, sleepGoalMet, waterBottlesLogged, waterGoalBottles, streak
        case sleepMessage, sleepWasRoast, waterMessage, waterWasRoast, updatedAt
        // Only ever present in a snapshot written before sleep/water messages
        // were split apart — read here so an old on-disk snapshot decodes
        // into real data instead of silently failing and reverting to
        // "nothing logged yet" on the next launch.
        case legacyMessage = "latestMessage"
        case legacyWasRoast = "latestWasRoast"
    }

    /// Custom decode so adding `sleepMessage`/`waterMessage` didn't brick
    /// whatever snapshot was already sitting in the app group's shared
    /// UserDefaults: a plain `Codable` decode throws on any missing key,
    /// which would silently discard the whole snapshot (including
    /// `sleepHours`/`waterBottlesLogged`, which are still there) rather than
    /// just the two genuinely-new fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try c.decode(String.self, forKey: .dayKey)
        sleepHours = try c.decodeIfPresent(Double.self, forKey: .sleepHours)
        sleepGoalMet = try c.decodeIfPresent(Bool.self, forKey: .sleepGoalMet)
        waterBottlesLogged = try c.decode(Int.self, forKey: .waterBottlesLogged)
        waterGoalBottles = try c.decode(Int.self, forKey: .waterGoalBottles)
        streak = try c.decode(Int.self, forKey: .streak)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)

        let legacyMessage = try c.decodeIfPresent(String.self, forKey: .legacyMessage)
        let legacyWasRoast = try c.decodeIfPresent(Bool.self, forKey: .legacyWasRoast) ?? false

        sleepMessage = try c.decodeIfPresent(String.self, forKey: .sleepMessage)
            ?? legacyMessage
            ?? sleepHours.map { "\(String(format: "%.1f", $0))h logged." }
            ?? "No sleep logged yet."
        sleepWasRoast = try c.decodeIfPresent(Bool.self, forKey: .sleepWasRoast) ?? legacyWasRoast

        waterMessage = try c.decodeIfPresent(String.self, forKey: .waterMessage)
            ?? legacyMessage
            ?? (waterBottlesLogged > 0 ? "\(waterBottlesLogged) of \(waterGoalBottles) bottles logged." : "No water logged yet.")
        waterWasRoast = try c.decodeIfPresent(Bool.self, forKey: .waterWasRoast) ?? legacyWasRoast
    }

    /// Written out explicitly (rather than relying on synthesis) since the
    /// legacy-only `CodingKeys` cases used for decode aren't backed by a
    /// stored property.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dayKey, forKey: .dayKey)
        try c.encodeIfPresent(sleepHours, forKey: .sleepHours)
        try c.encodeIfPresent(sleepGoalMet, forKey: .sleepGoalMet)
        try c.encode(waterBottlesLogged, forKey: .waterBottlesLogged)
        try c.encode(waterGoalBottles, forKey: .waterGoalBottles)
        try c.encode(streak, forKey: .streak)
        try c.encode(sleepMessage, forKey: .sleepMessage)
        try c.encode(sleepWasRoast, forKey: .sleepWasRoast)
        try c.encode(waterMessage, forKey: .waterMessage)
        try c.encode(waterWasRoast, forKey: .waterWasRoast)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    static let placeholder = TodaySnapshot(
        dayKey: Date().dayKey,
        sleepHours: 6.5,
        sleepGoalMet: true,
        waterBottlesLogged: 2,
        waterGoalBottles: 4,
        streak: 3,
        sleepMessage: "6.5 hours. Fine, I suppose.",
        sleepWasRoast: false,
        waterMessage: "Two bottles down. Acceptable.",
        waterWasRoast: false,
        updatedAt: .now
    )
}

struct AppSettings: Codable, Sendable {
    var waterGoalBottles: Int = 4
    var bottleSizeMl: Int = 750
    var checkInHours: [CheckInWindow: Int] = [
        .morning: CheckInWindow.morning.defaultHour,
        .afternoon: CheckInWindow.afternoon.defaultHour,
        .night: CheckInWindow.night.defaultHour,
    ]
    var roastIntensity: RoastIntensity = .playful
    var healthKitEnabled: Bool = false
    var onboardingComplete: Bool = false
}
