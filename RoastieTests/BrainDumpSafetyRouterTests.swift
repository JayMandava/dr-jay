import XCTest
@testable import Roastie

final class BrainDumpSafetyRouterTests: XCTestCase {
    func testOrdinaryStressUsesConversation() {
        XCTAssertEqual(
            BrainDumpSafetyRouter.route("Work was exhausting and my brain will not switch off"),
            .conversation
        )
    }

    func testMedicalRequestIsRefusedWithoutModelJudgment() {
        XCTAssertEqual(BrainDumpSafetyRouter.route("Can you diagnose me?"), .prohibitedAdvice)
        XCTAssertEqual(BrainDumpSafetyRouter.route("What medication should I take?"), .prohibitedAdvice)
    }

    func testRealityDistortionGetsCalmResponsePath() {
        XCTAssertEqual(BrainDumpSafetyRouter.route("They are watching me"), .vulnerable)
        XCTAssertEqual(BrainDumpSafetyRouter.route("I am hearing voices"), .vulnerable)
    }

    func testSelfHarmAlwaysTakesImmediateRiskPath() {
        XCTAssertEqual(BrainDumpSafetyRouter.route("I want to kill myself"), .immediateRisk)
        XCTAssertEqual(BrainDumpSafetyRouter.route("I do not want to live"), .immediateRisk)
    }
}
