import Foundation
import ActivityKit

/// Shared between the app (which starts/updates the activity) and the
/// widget extension (which renders it in the Dynamic Island / Lock Screen).
struct RoastieActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var sleepHours: Double?
        var sleepGoalMet: Bool?
        var waterBottlesLogged: Int
        var waterGoalBottles: Int
        var sleepMessage: String
        var sleepWasRoast: Bool
        var waterMessage: String
        var waterWasRoast: Bool
        var nextCheckInLabel: String
        var streak: Int

        var waterProgress: Double {
            guard waterGoalBottles > 0 else { return 0 }
            return min(1, Double(waterBottlesLogged) / Double(waterGoalBottles))
        }

        var sleepProgress: Double {
            min(1, (sleepHours ?? 0) / AppConfig.sleepGoalHours)
        }
    }

    var startedDayKey: String
}

extension RoastieActivityAttributes.ContentState {
    init(snapshot: TodaySnapshot, nextCheckInLabel: String) {
        self.sleepHours = snapshot.sleepHours
        self.sleepGoalMet = snapshot.sleepGoalMet
        self.waterBottlesLogged = snapshot.waterBottlesLogged
        self.waterGoalBottles = snapshot.waterGoalBottles
        self.sleepMessage = snapshot.sleepMessage
        self.sleepWasRoast = snapshot.sleepWasRoast
        self.waterMessage = snapshot.waterMessage
        self.waterWasRoast = snapshot.waterWasRoast
        self.nextCheckInLabel = nextCheckInLabel
        self.streak = snapshot.streak
    }
}
