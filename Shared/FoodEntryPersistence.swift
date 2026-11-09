import Foundation

enum FoodEntryPersistenceError: LocalizedError {
    case emptyDescription
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .emptyDescription: "Tell Dr Jay what you ate before logging food."
        case .saveFailed: "Your food entry could not be saved. Open Dr Jay to check before trying again."
        }
    }
}

@MainActor
enum FoodEntryPersistence {
    /// Persist exactly one food entry, never a hydration or sleep mutation.
    /// The original description is retained if later model assessment is unavailable.
    static func insert(
        description: String,
        in log: DailyLog,
        now: Date = .now,
        save: () -> Bool
    ) throws -> FoodEntry {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FoodEntryPersistenceError.emptyDescription }
        let originalEntries = log.foodEntries
        let originalScore = log.foodScore
        let originalSummary = log.foodScoreSummary
        let originalCurrent = log.foodScoreIsCurrent
        let originalVersion = log.foodScoreVersion
        let entry = FoodEntry(text: text, timestamp: now, verdict: .unanalyzed, assessment: nil, roast: nil)
        log.foodEntries = (originalEntries ?? []) + [entry]
        log.foodScore = log.foodScoreAggregate.score
        log.foodScoreSummary = nil
        log.foodScoreIsCurrent = false
        log.foodScoreVersion = nil
        guard save() else {
            log.foodEntries = originalEntries
            log.foodScore = originalScore
            log.foodScoreSummary = originalSummary
            log.foodScoreIsCurrent = originalCurrent
            log.foodScoreVersion = originalVersion
            throw FoodEntryPersistenceError.saveFailed
        }
        return entry
    }
}

/// Cancellation or failed confirmation must stop before touching the log/store.
@MainActor
enum SiriWaterConfirmation {
    static func run(
        confirm: () async throws -> Void,
        save: () throws -> SiriLogReceipt
    ) async throws -> SiriLogReceipt {
        try await confirm()
        return try save()
    }
}
