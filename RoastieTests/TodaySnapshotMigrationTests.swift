import XCTest
@testable import Roastie

final class TodaySnapshotMigrationTests: XCTestCase {
    func testLegacyMessagePopulatesBothStatusMessages() throws {
        let legacy = LegacySnapshot(
            dayKey: "2026-09-23",
            sleepHours: 7,
            sleepGoalMet: true,
            waterBottlesLogged: 2,
            waterGoalBottles: 4,
            streak: 3,
            latestMessage: "Legacy check-in",
            latestWasRoast: true,
            updatedAt: TestSupport.date(23)
        )

        let snapshot = try JSONDecoder().decode(
            TodaySnapshot.self,
            from: JSONEncoder().encode(legacy)
        )

        XCTAssertEqual(snapshot.sleepMessage, "Legacy check-in")
        XCTAssertEqual(snapshot.waterMessage, "Legacy check-in")
        XCTAssertTrue(snapshot.sleepWasRoast)
        XCTAssertTrue(snapshot.waterWasRoast)
        XCTAssertEqual(snapshot.sleepHours, 7)
        XCTAssertEqual(snapshot.waterBottlesLogged, 2)
    }
}

private struct LegacySnapshot: Codable {
    let dayKey: String
    let sleepHours: Double?
    let sleepGoalMet: Bool?
    let waterBottlesLogged: Int
    let waterGoalBottles: Int
    let streak: Int
    let latestMessage: String
    let latestWasRoast: Bool
    let updatedAt: Date
}
