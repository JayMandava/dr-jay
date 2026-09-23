import XCTest
@testable import Roastie

final class CheckInWindowResolverTests: XCTestCase {
    private var settings: AppSettings {
        var settings = AppSettings()
        settings.checkInHours = [.morning: 7, .afternoon: 13, .night: 23]
        return settings
    }

    func testUsesCustomizedExactCheckInTime() {
        XCTAssertEqual(
            CheckInWindowResolver.closest(
                to: TestSupport.date(23, hour: 13),
                settings: settings,
                calendar: TestSupport.calendar
            ),
            .afternoon
        )
    }

    func testTieUsesEarlierCheckIn() {
        XCTAssertEqual(
            CheckInWindowResolver.closest(
                to: TestSupport.date(23, hour: 10),
                settings: settings,
                calendar: TestSupport.calendar
            ),
            .morning
        )
    }

    func testSelectionWrapsAcrossMidnight() {
        XCTAssertEqual(
            CheckInWindowResolver.closest(
                to: TestSupport.date(23, hour: 0),
                settings: settings,
                calendar: TestSupport.calendar
            ),
            .night
        )
    }
}
