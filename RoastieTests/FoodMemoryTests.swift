import XCTest
@testable import Roastie

final class FoodMemoryTests: XCTestCase {
    func testNormalizationMakesEquivalentDescriptionsAnExactMatch() {
        let memories = FoodMemoryStore.upserting(
            food: "  Paneer-Tikka! ",
            verdict: .healthy,
            at: TestSupport.date(22),
            in: []
        )

        let match = FoodMemoryMatcher.exactMatch(for: "paneer tikka", in: memories)

        XCTAssertEqual(match?.verdict, .healthy)
        XCTAssertEqual(match?.displayText, "Paneer-Tikka!")
    }

    func testLatestCorrectionWinsAndCountsConfirmations() {
        let first = FoodMemoryStore.upserting(
            food: "Granola",
            verdict: .healthy,
            at: TestSupport.date(21),
            in: []
        )
        let corrected = FoodMemoryStore.upserting(
            food: "granola",
            verdict: .unhealthy,
            at: TestSupport.date(22),
            in: first
        )

        XCTAssertEqual(corrected.count, 1)
        XCTAssertEqual(corrected.first?.verdict, .unhealthy)
        XCTAssertEqual(corrected.first?.confirmationCount, 2)
        XCTAssertEqual(corrected.first?.correctedAt, TestSupport.date(22))
    }

    func testImportedNewerMemoryReplacesLocalMemory() {
        let local = FoodMemoryStore.upserting(
            food: "Dosa",
            verdict: .unhealthy,
            at: TestSupport.date(21),
            in: []
        )
        let imported = FoodMemoryStore.upserting(
            food: "dosa",
            verdict: .healthy,
            at: TestSupport.date(23),
            in: []
        )

        let merged = FoodMemoryStore.merging(existing: local, imported: imported)

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.verdict, .healthy)
    }
}
