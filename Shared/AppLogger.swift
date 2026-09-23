import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = "dev.jeyanth.roastie"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let backup = Logger(subsystem: subsystem, category: "backup")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let background = Logger(subsystem: subsystem, category: "background")
    static let activity = Logger(subsystem: subsystem, category: "live-activity")
    static let health = Logger(subsystem: subsystem, category: "health")
    static let food = Logger(subsystem: subsystem, category: "food")
    static let sharedStore = Logger(subsystem: subsystem, category: "shared-store")

    static func report(_ error: Error, operation: String, logger: Logger) {
        logger.error("\(operation, privacy: .public) failed: \(String(describing: error), privacy: .public)")
    }
}
