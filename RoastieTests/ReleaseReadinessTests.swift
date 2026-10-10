import XCTest
@testable import Roastie

final class ReleaseReadinessTests: XCTestCase {
    func testDevelopmentProfileUsesActualExpiry() {
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(AppConfig.developmentExpiry(in: [
            "Entitlements": ["get-task-allow": true],
            "ExpirationDate": expiry
        ]), expiry)
    }

    func testDistributionProfileDoesNotShowSigningExpiry() {
        XCTAssertNil(AppConfig.developmentExpiry(in: [
            "Entitlements": ["get-task-allow": false],
            "ExpirationDate": Date()
        ]))
    }

    func testMissingOrIncompleteProfileDoesNotInventExpiry() {
        XCTAssertNil(AppConfig.developmentExpiry(in: [:]))
        XCTAssertNil(AppConfig.developmentExpiry(in: ["ExpirationDate": Date()]))
        XCTAssertNil(AppConfig.developmentExpiry(in: ["Entitlements": ["get-task-allow": true]]))
    }

    func testPolicyAndLicenseResourcesAreBundled() throws {
        // Hosted tests use the app bundle, not the XCTest bundle.
        for (name, ext) in [("PRIVACY", "md"), ("LICENSE", ""), ("NOTICE", ""), ("PrivacyInfo", "xcprivacy")] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext))
            XCTAssertGreaterThan(try Data(contentsOf: url).count, 0)
        }
    }
}
