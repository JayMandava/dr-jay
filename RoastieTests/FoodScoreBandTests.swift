import XCTest
@testable import Roastie

final class FoodScoreBandTests: XCTestCase {
    func testGoodStartsAtEighty() {
        XCTAssertEqual(FoodScoreBand.classify(80), .good)
        XCTAssertEqual(FoodScoreBand.classify(100), .good)
    }

    func testBadCoversSixtyThroughSeventyNine() {
        XCTAssertEqual(FoodScoreBand.classify(60), .bad)
        XCTAssertEqual(FoodScoreBand.classify(79), .bad)
    }

    func testUglyEndsAtFiftyNine() {
        XCTAssertEqual(FoodScoreBand.classify(0), .ugly)
        XCTAssertEqual(FoodScoreBand.classify(59), .ugly)
    }
}
