import XCTest
@testable import Roastie

final class BackupManagerTests: XCTestCase {
    func testBackupRoundTripAndRestorePreserveHistory() throws {
        let source = DailyLog(dayKey: "2026-09-23", date: TestSupport.date(23), waterGoalBottles: 5)
        source.sleepHours = 7.5
        source.sleepSource = "manual"
        source.waterBottlesLogged = 3
        source.waterTimestamps = [TestSupport.date(23, hour: 9)]
        source.checkIns = [CheckInRecord(
            window: .morning,
            kind: .sleep,
            timestamp: TestSupport.date(23, hour: 9),
            met: true,
            message: "Cleared",
            wasGeneratedByModel: false
        )]

        let url = FileManager.default.temporaryDirectory
            .appending(path: "roastie-backup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try BackupManager.write([source], to: url)
        let entry = try XCTUnwrap(BackupManager.read(from: url).logs.first)
        let restored = DailyLog(dayKey: entry.dayKey, date: .distantPast, waterGoalBottles: 1)
        BackupManager.restore(entry, into: restored)

        XCTAssertEqual(restored.date, source.date)
        XCTAssertEqual(restored.sleepHours, source.sleepHours)
        XCTAssertEqual(restored.sleepSource, "manual")
        XCTAssertEqual(restored.waterGoalBottles, 5)
        XCTAssertEqual(restored.waterBottlesLogged, 3)
        XCTAssertEqual(restored.waterTimestamps, source.waterTimestamps)
        XCTAssertEqual(restored.checkIns, source.checkIns)
    }
}
