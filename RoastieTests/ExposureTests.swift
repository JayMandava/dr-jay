import XCTest
import SwiftData
import SwiftUI
@testable import Roastie

final class ExposureTests: XCTestCase {
    func testOnlyWholeCommandsUnlockLedger() {
        for text in ["Spirits", " spirits ", "\nSPIRITS\t"] {
            XCTAssertEqual(HiddenLogCommand.match(text), .alcohol)
        }
        for text in ["Smoke", "\n smoke "] { XCTAssertEqual(HiddenLogCommand.match(text), .smoke) }
        for text in ["", "spirits today", "I smoke", "smoked", "Spirits!", "Spirit", "Spirits\nSmoke", "smoke-free", "👻spirits"] {
            XCTAssertNil(HiddenLogCommand.match(text), text)
        }
    }

    func testPolicyZeroBoundaryExcessAndCombinedDeductions() {
        XCTAssertEqual(ExposureSummary().penalty, 0)
        XCTAssertEqual(ExposureSummary(alcoholUnits: 0.5).penalty, 4)
        XCTAssertEqual(ExposureSummary(alcoholUnits: 2.5).penalty, 26)
        XCTAssertEqual(ExposureSummary(alcoholUnits: 2.275).penalty, 22)
        XCTAssertEqual(ExposureSummary(alcoholUnits: .nan, cigarettes: 0).penalty, 0)
        XCTAssertEqual(ExposureSummary(alcoholUnits: .infinity, cigarettes: 0).penalty, 0)
        XCTAssertEqual(ExposureSummary(alcoholUnits: 1).penalty, 8)
        XCTAssertEqual(ExposureSummary(alcoholUnits: 2).penalty, 16)
        XCTAssertFalse(ExposureSummary(alcoholUnits: 2).exceedsAlcoholThreshold)
        XCTAssertEqual(ExposureSummary(alcoholUnits: 3).penalty, 36)
        XCTAssertTrue(ExposureSummary(alcoholUnits: 3).exceedsAlcoholThreshold)
        XCTAssertEqual(ExposureSummary(cigarettes: 1).penalty, 20)
        XCTAssertEqual(ExposureSummary(cigarettes: 2).penalty, 40)
        XCTAssertEqual(ExposureSummary(alcoholUnits: 3, cigarettes: 2).penalty, 76)
        XCTAssertEqual(ExposureSummary(alcoholUnits: -1, cigarettes: -10).penalty, 0)
        XCTAssertEqual(ExposureSummary(alcoholUnits: Double.greatestFiniteMagnitude, cigarettes: Int.max).penalty, 100)
    }

    func testMonotonicBoundedScoresAcrossAllProfilesAndPartialDays() {
        for profile in DailyScoreProfile.allCases {
            for complete in [true, false] {
                for smoke in [false, true] {
                    var previous = 100
                    for units in 0...120 {
                        let result = DailySummaryCalculator.calculate(input(
                            ExposureSummary(alcoholUnits: smoke ? 0 : Double(units), cigarettes: smoke ? units : 0),
                            complete: complete), profile: profile)
                        XCTAssertTrue((0...100).contains(result.score))
                        XCTAssertLessThanOrEqual(result.score, previous)
                        XCTAssertEqual(result.band, DailySummaryBand.classify(result.score))
                        previous = result.score
                    }
                    XCTAssertEqual(previous, 0)
                }
            }
        }
    }

    func testExposureRoastOverridesOnlyExposureFeedback() {
        let exposure = ExposureSummary(alcoholUnits: 3, cigarettes: 1)
        let gentle = DailySummaryCalculator.calculate(input(exposure), intensity: .gentle, foodRoastsEnabled: false)
        let spicy = DailySummaryCalculator.calculate(input(exposure), intensity: .spicy)
        XCTAssertEqual(gentle.roast, spicy.roast)
        XCTAssertEqual(gentle.score, 44)
        XCTAssertTrue(gentle.detail.contains("Score −56"))
        XCTAssertTrue(gentle.roast.contains("every cigarette"))
        let noExposure = DailySummaryCalculator.calculate(input())
        XCTAssertEqual(noExposure.score, 100)
        XCTAssertFalse(noExposure.detail.contains("Alcohol"))
    }

    func testReportIncludesExposureEvenWithIncompleteDayAndNoModel() async {
        let exposure = ExposureSummary(alcoholUnits: 3, cigarettes: 1)
        let value = input(exposure, complete: false)
        let result = DailySummaryCalculator.calculate(value)
        let report = await DailyReportGenerator.generate(input: value, result: result, intensity: .gentle,
            foodRoastsEnabled: false, provider: .gemma)
        XCTAssertTrue(report.contains("incomplete"))
        XCTAssertTrue(report.contains(exposure.detail))
        XCTAssertTrue(report.contains(exposure.roast))
        XCTAssertTrue(report.contains("not a medical risk score"))
    }

    func testLedgerMutationInvalidatesOnlySelectedDaysPendingAndDeliveredSummary() {
        let dayKey = "2026-11-06"
        let selectedID = "daily.summary.2026-11-06"
        let otherIDs: Set<String> = ["daily.summary.2026-11-05", "daily.summary.2026-11-07",
                                     "sleep.night.2026-11-06", "water.night.2026-11-06",
                                     "backup.expiry.reminder"]
        var pending = otherIDs.union([selectedID])
        var delivered = otherIDs.union([selectedID])
        var pendingIDs: [String] = []
        var deliveredIDs: [String] = []
        NotificationManager.invalidateDailySummary(for: dayKey, removePending: { identifiers in
            pendingIDs = identifiers
            pending.subtract(identifiers)
        }, removeDelivered: { identifiers in
            deliveredIDs = identifiers
            delivered.subtract(identifiers)
        })
        XCTAssertEqual(NotificationManager.dailySummaryIdentifier(for: dayKey), selectedID)
        XCTAssertEqual(pendingIDs, [selectedID])
        XCTAssertEqual(deliveredIDs, [selectedID])
        XCTAssertEqual(pending, otherIDs)
        XCTAssertEqual(delivered, otherIDs)
        // Historical corrections target only that historical day's notification, too.
        NotificationManager.invalidateDailySummary(for: "2026-11-05", removePending: { pending.subtract($0) },
                                                    removeDelivered: { delivered.subtract($0) })
        XCTAssertFalse(delivered.contains("daily.summary.2026-11-05"))
        XCTAssertFalse(pending.contains("daily.summary.2026-11-05"))
        XCTAssertTrue(delivered.contains("water.night.2026-11-06"))
        XCTAssertTrue(pending.contains("daily.summary.2026-11-07"))
    }

    func testModelVariationPromptsContainOnlyFixedAppAuthoredCues() {
        for angle in DailyReportPrompt.ComicAngle.allCases {
            XCTAssertEqual(DailyReportPrompt.variation(angle: angle),
                           "Optional comic angle: \(angle.rawValue). Write one fresh roast sentence.")
        }
    }

    func testDeletedExposureReportIsExcludedFromSubsequentModelPrompts() async {
        let exposures = ExposureSummary(alcoholUnits: 3, cigarettes: 1)
        let previousInput = input(exposures)
        let previousReport = await DailyReportGenerator.generate(
            input: previousInput, result: DailySummaryCalculator.calculate(previousInput),
            intensity: .gentle, foodRoastsEnabled: false, provider: .gemma)
        XCTAssertTrue(previousReport.contains(exposures.detail))
        let emptyLedger = input()
        XCTAssertTrue(emptyLedger.exposures.isEmpty)
        // Both providers use this builder, which deliberately accepts no previous report.
        // Repetition checks still receive previousReport locally, outside model prompts.
        for angle in DailyReportPrompt.ComicAngle.allCases {
            let prompt = DailyReportPrompt.variation(angle: angle)
            XCTAssertEqual(prompt, "Optional comic angle: \(angle.rawValue). Write one fresh roast sentence.")
            XCTAssertFalse(prompt.contains(previousReport))
            XCTAssertFalse(prompt.contains(exposures.detail))
            XCTAssertFalse(prompt.contains(exposures.roast))
            XCTAssertFalse(prompt.contains("<previous>"))
        }
    }

    func testTotalsAreOrderIndependentAndOverflowSafe() {
        let entries = [ExposureEntry(kind: .alcohol, quantity: Double.greatestFiniteMagnitude, timestamp: .now),
                       ExposureEntry(kind: .alcohol, quantity: 1, timestamp: .now),
                       ExposureEntry(kind: .smoke, quantity: -10, timestamp: .now)]
        XCTAssertEqual(ExposureSummary(entries: entries), ExposureSummary(entries: entries.reversed()))
        XCTAssertEqual(ExposureSummary(entries: entries).alcoholUnits, Double.greatestFiniteMagnitude)
        XCTAssertEqual(ExposureSummary(entries: entries).cigarettes, 0)
        XCTAssertEqual(ExposureSummary(entries: entries).penalty, 100)
    }

    func testDecimalAlcoholRoundingIsIndependentOfAllEntryPermutations() {
        let permutations = [[0.822, 0.599, 0.654], [0.822, 0.654, 0.599],
                            [0.599, 0.822, 0.654], [0.599, 0.654, 0.822],
                            [0.654, 0.822, 0.599], [0.654, 0.599, 0.822]]
        for values in permutations {
            let summary = ExposureSummary(entries: values.map { ExposureEntry(kind: .alcohol, quantity: $0, timestamp: .now) })
            XCTAssertEqual(summary.alcoholUnits, 2.075)
            XCTAssertEqual(summary.penalty, 18)
            XCTAssertEqual(DailySummaryCalculator.calculate(input(summary)).score, 82)
        }
    }

    @MainActor
    func testSaveAndDeleteFailureRollBackEntries() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let date = TestSupport.date(23)
        let original = ExposureEntry(kind: .smoke, quantity: 1, timestamp: date)
        do {
            let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
            _ = try ExposureLogStore.save(original, dayKey: date.dayKey, context: ModelContext(container), waterGoal: 4)
        }
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url, allowsSave: false))
        let context = ModelContext(container)
        let log = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyLog>()).first)
        var correction = original
        correction.quantity = 2
        XCTAssertThrowsError(try ExposureLogStore.save(correction, dayKey: date.dayKey, context: context, waterGoal: 4))
        XCTAssertEqual(log.exposureEntries, [original])
        XCTAssertThrowsError(try ExposureLogStore.delete(id: original.id, dayKey: date.dayKey, context: context))
        XCTAssertEqual(log.exposureEntries, [original])
    }

    @MainActor
    func testDiskPersistenceCorrectionDeletionAndDayIsolation() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "history.store")
        let date = TestSupport.date(23)
        let otherDate = TestSupport.date(24)
        var entry = ExposureEntry(kind: .alcohol, quantity: 3, timestamp: date, note: "Wedding")
        let other = ExposureEntry(kind: .smoke, quantity: 1, timestamp: otherDate)
        func open() throws -> ModelContainer {
            try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(url: url))
        }
        do {
            let container = try open()
            let context = ModelContext(container)
            let log = try ExposureLogStore.save(entry, dayKey: date.dayKey, context: context, waterGoal: 4)
            XCTAssertEqual(ExposureSummary(entries: log.exposureEntries ?? []).penalty, 36)
            _ = try ExposureLogStore.save(other, dayKey: otherDate.dayKey, context: context, waterGoal: 4)
        }
        do {
            let container = try open()
            let context = ModelContext(container)
            let logs = try context.fetch(FetchDescriptor<DailyLog>())
            XCTAssertEqual(logs.count, 2)
            XCTAssertEqual(logs.first { $0.dayKey == date.dayKey }?.exposureEntries, [entry])
            entry.quantity = 1
            let corrected = try ExposureLogStore.save(entry, dayKey: date.dayKey, context: context, waterGoal: 4)
            XCTAssertEqual(corrected.exposureEntries?.count, 1)
            XCTAssertEqual(ExposureSummary(entries: corrected.exposureEntries ?? []).penalty, 8)
        }
        do {
            let container = try open()
            let context = ModelContext(container)
            let log = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyLog>()).first { $0.dayKey == date.dayKey })
            XCTAssertEqual(log.exposureEntries, [entry])
            _ = try ExposureLogStore.delete(id: entry.id, dayKey: date.dayKey, context: context)
        }
        do {
            let container = try open()
            let logs = try ModelContext(container).fetch(FetchDescriptor<DailyLog>())
            XCTAssertEqual(logs.first { $0.dayKey == date.dayKey }?.exposureEntries, [])
            XCTAssertEqual(ExposureSummary(entries: logs.first { $0.dayKey == date.dayKey }?.exposureEntries ?? []).penalty, 0)
            XCTAssertEqual(logs.first { $0.dayKey == otherDate.dayKey }?.exposureEntries, [other])
        }
    }

    @MainActor
    func testValidationRejectsZeroNegativeHugeFutureAndWrongDayWithoutMutation() throws {
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let date = TestSupport.date(23)
        for quantity in [0, -1, 1001, Int.max] {
            XCTAssertThrowsError(try ExposureLogStore.save(ExposureEntry(kind: .smoke, quantity: Double(quantity), timestamp: date), dayKey: date.dayKey, context: context, waterGoal: 4))
        }
        XCTAssertThrowsError(try ExposureLogStore.save(ExposureEntry(kind: .alcohol, quantity: 1, timestamp: .distantFuture), dayKey: Date.distantFuture.dayKey, context: context, waterGoal: 4))
        XCTAssertThrowsError(try ExposureLogStore.save(ExposureEntry(kind: .alcohol, quantity: 1, timestamp: date), dayKey: "wrong", context: context, waterGoal: 4))
        XCTAssertThrowsError(try ExposureLogStore.save(ExposureEntry(kind: .alcohol, quantity: 1, timestamp: date, note: String(repeating: "x", count: 501)), dayKey: date.dayKey, context: context, waterGoal: 4))
        for (kind, quantity) in [(ExposureKind.smoke, 1.5), (.alcohol, 0.25), (.alcohol, Double.nan), (.alcohol, Double.infinity)] {
            XCTAssertThrowsError(try ExposureLogStore.save(ExposureEntry(kind: kind, quantity: quantity, timestamp: date), dayKey: date.dayKey, context: context, waterGoal: 4))
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyLog>()).isEmpty)
    }

    func testBackupRoundTripAndLegacyMissingExposureEntries() throws {
        let source = DailyLog(dayKey: TestSupport.date(23).dayKey, date: TestSupport.date(23), waterGoalBottles: 4)
        source.exposureEntries = [ExposureEntry(kind: .alcohol, quantity: 3, timestamp: TestSupport.date(23), note: "Dinner")]
        let url = FileManager.default.temporaryDirectory.appending(path: "exposure-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try BackupManager.write([source], to: url)
        let payload = try BackupManager.read(from: url)
        XCTAssertEqual(payload.version, 9)
        let restored = DailyLog(dayKey: source.dayKey, date: source.date, waterGoalBottles: 4)
        BackupManager.restore(try XCTUnwrap(payload.logs.first), into: restored)
        XCTAssertEqual(restored.exposureEntries, source.exposureEntries)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["version"] = 8
        var logs = try XCTUnwrap(json["logs"] as? [[String: Any]])
        logs[0].removeValue(forKey: "exposureEntries")
        json["logs"] = logs
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let legacy = try BackupManager.read(from: url)
        XCTAssertNil(legacy.logs.first?.exposureEntries)
        BackupManager.restore(try XCTUnwrap(legacy.logs.first), into: restored)
        XCTAssertEqual(restored.exposureEntries, [])
    }

    @MainActor
    func testHiddenLedgerRendersBothEntryPoints() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let container = try ModelContainer(for: DailyLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        for kind in ExposureKind.allCases {
            let window = UIWindow(windowScene: scene)
            window.frame = scene.coordinateSpace.bounds
            window.windowLevel = .normal + 1
            let host = UIHostingController(rootView: HiddenExposureSheet(initialKind: kind).modelContainer(container))
            window.rootViewController = host
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(1))
            XCTAssertGreaterThan(host.view.bounds.width, 0)
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "hidden-ledger-\(kind.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let url = FileManager.default.temporaryDirectory.appending(path: "hidden-ledger-\(kind.rawValue).png")
            try image.pngData()?.write(to: url)
            print("HIDDEN_LEDGER_IMAGE \(url.path)")
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    private func input(_ exposures: ExposureSummary = ExposureSummary(), complete: Bool = true) -> DailySummaryInput {
        DailySummaryInput(sleepHours: complete ? 7 : nil, waterBottlesLogged: 4, waterGoalBottles: 4,
                          foodScore: complete ? 100 : nil, steps: 8000, exerciseMinutes: nil,
                          exerciseEntryCount: 0, exposures: exposures)
    }
}
