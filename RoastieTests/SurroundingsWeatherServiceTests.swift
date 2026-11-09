import CoreLocation
import XCTest
@testable import Roastie

final class SurroundingsWeatherServiceTests: XCTestCase {
    @MainActor
    func testDisabledRefreshDoesNotCreateLocationManager() {
        var managerCreations = 0
        let service = SurroundingsWeatherService(makeLocationManager: {
            managerCreations += 1
            return NoPermissionLocationManager()
        })
        service.refresh()
        XCTAssertFalse(service.enabled)
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.snapshot)
        XCTAssertEqual(managerCreations, 0)
    }

    @MainActor
    func testEnablingAloneDoesNotRequestLocationOrPermission() {
        var managerCreations = 0
        let service = SurroundingsWeatherService(makeLocationManager: {
            managerCreations += 1
            return NoPermissionLocationManager()
        })
        service.setEnabled(true)
        XCTAssertTrue(service.enabled)
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.snapshot)
        XCTAssertEqual(managerCreations, 0)
        XCTAssertTrue(service.statusMessage?.contains("Check Weather") == true)
        service.setEnabled(false)
    }

    @MainActor
    func testDisableCancelsPendingPermissionAndIgnoresLateCallbacks() {
        let manager = NoPermissionLocationManager()
        let service = SurroundingsWeatherService(makeLocationManager: { manager })
        service.setEnabled(true)
        service.refresh()
        XCTAssertTrue(service.isLoading)
        service.setEnabled(false)
        XCTAssertFalse(service.enabled)
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.snapshot)
        XCTAssertNil(service.statusMessage)
        XCTAssertNil(manager.delegate)

        // Simulate callbacks already queued when the feature was switched off.
        service.locationManagerDidChangeAuthorization(manager)
        service.locationManager(manager, didFailWithError: CLError(.denied))
        service.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 51.5, longitude: -0.1)])
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.snapshot)
        XCTAssertNil(service.statusMessage)
    }

    @MainActor
    func testOldManagerCannotAffectReenabledRequest() {
        let oldManager = NoPermissionLocationManager()
        let newManager = NoPermissionLocationManager()
        var managerCreations = 0
        let service = SurroundingsWeatherService(makeLocationManager: {
            managerCreations += 1
            return managerCreations == 1 ? oldManager : newManager
        })
        service.setEnabled(true)
        service.refresh()
        service.setEnabled(false)
        service.setEnabled(true)
        service.refresh()
        let message = service.statusMessage
        service.locationManager(oldManager, didFailWithError: CLError(.denied))
        service.locationManagerDidChangeAuthorization(oldManager)
        service.locationManager(oldManager, didUpdateLocations: [CLLocation(latitude: 51.5, longitude: -0.1)])
        XCTAssertTrue(service.isLoading)
        XCTAssertEqual(service.statusMessage, message)
        XCTAssertNil(service.snapshot)
        service.setEnabled(false)
    }
}

/// Never displays a permission dialog or starts location/network work in tests.
private final class NoPermissionLocationManager: CLLocationManager {
    override var authorizationStatus: CLAuthorizationStatus { .notDetermined }
    override func requestWhenInUseAuthorization() {}
    override func requestLocation() {}
    override func stopUpdatingLocation() {}
}
