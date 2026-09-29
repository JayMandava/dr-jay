import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoodAssessment: Sendable {
    var verdict: FoodVerdict
    var explanation: String
    var roast: String?
    var qualityScore: Int
    var caffeineCount: Int?
    var sugaryItemCount: Int?
}

struct DailyFoodAssessment: Sendable {
    var score: Int
    var summary: String?
}

/// Converts bounded per-entry nutrition quality into a stable daily score.
/// The arithmetic mean is intentionally order-independent.
enum FoodScoreCalculator {
    static let version = 2

    static func score(entries: [FoodEntry]) -> Int? {
        guard !entries.isEmpty else { return nil }
        let scores = entries.compactMap(entryScore)
        guard scores.count == entries.count else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    static func normalized(_ score: Int, for verdict: FoodVerdict) -> Int? {
        switch verdict {
        case .healthy:
            min(100, max(80, score))
        case .unhealthy:
            min(59, max(0, score))
        case .unanalyzed:
            nil
        }
    }

    static func defaultScore(for verdict: FoodVerdict) -> Int? {
        switch verdict {
        case .healthy: 90
        case .unhealthy: 30
        case .unanalyzed: nil
        }
    }

    private static func entryScore(_ entry: FoodEntry) -> Int? {
        guard let candidate = entry.qualityScore ?? defaultScore(for: entry.verdict) else {
            return nil
        }
        return normalized(candidate, for: entry.verdict)
    }
}

struct FoodExposureTotals: Equatable, Sendable {
    var caffeineCount: Int
    var sugaryItemCount: Int
    var trackedEntries: Int
    var totalEntries: Int

    var hasUntrackedEntries: Bool { trackedEntries < totalEntries }
}

/// Sums only model-confirmed exposure tags. Legacy and failed analyses remain
/// visibly untracked instead of being silently treated as zero.
enum FoodExposureCalculator {
    static let maximumCountPerEntry = 12

    static func normalized(_ count: Int) -> Int {
        min(maximumCountPerEntry, max(0, count))
    }

    static func totals(entries: [FoodEntry]) -> FoodExposureTotals {
        var caffeineCount = 0
        var sugaryItemCount = 0
        var trackedEntries = 0

        for entry in entries {
            guard let caffeine = entry.caffeineCount,
                  let sugary = entry.sugaryItemCount else { continue }
            caffeineCount += normalized(caffeine)
            sugaryItemCount += normalized(sugary)
            trackedEntries += 1
        }

        return FoodExposureTotals(
            caffeineCount: caffeineCount,
            sugaryItemCount: sugaryItemCount,
            trackedEntries: trackedEntries,
            totalEntries: entries.count
        )
    }
}

/// Classifies a plain-language food entry locally. No food text leaves the
/// device. An unavailable model returns nil so the caller can preserve the
/// entry as explicitly unanalyzed rather than guessing.
enum FoodAnalyzer {
    static func analyze(
        _ food: String,
        intensity: RoastIntensity,
        exactMemory: FoodCorrectionMemory? = nil,
        relatedMemories: [FoodCorrectionMemory] = []
    ) async -> FoodAssessment? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let result = await analyzeOnDevice(
                food,
                intensity: intensity,
                exactMemory: exactMemory,
                relatedMemories: relatedMemories
            ) {
                return result
            }
        }
        #endif
        return exactMemory.map { rememberedAssessment(for: $0, intensity: intensity) }
    }

    static func scoreDay(
        entries: [FoodEntry],
        intensity: RoastIntensity
    ) async -> DailyFoodAssessment? {
        guard let score = FoodScoreCalculator.score(entries: entries) else { return nil }

        let summary: String?
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            summary = await summarizeDayOnDevice(entries: entries, score: score, intensity: intensity)
        } else {
            summary = nil
        }
        #else
        summary = nil
        #endif

        return DailyFoodAssessment(score: score, summary: summary)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func analyzeOnDevice(
        _ food: String,
        intensity: RoastIntensity,
        exactMemory: FoodCorrectionMemory?,
        relatedMemories: [FoodCorrectionMemory]
    ) async -> FoodAssessment? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        let session = LanguageModelSession(instructions: entryInstructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: entryPrompt(
                    food: food,
                    exactMemory: exactMemory,
                    relatedMemories: relatedMemories
                ),
                generating: GeneratedFoodAssessment.self
            )
            let verdict = exactMemory?.verdict
                ?? (response.content.isHealthy ? FoodVerdict.healthy : FoodVerdict.unhealthy)
            let candidateScore = exactMemory.flatMap { FoodScoreCalculator.defaultScore(for: $0.verdict) }
                ?? response.content.qualityScore
            guard let qualityScore = FoodScoreCalculator.normalized(
                candidateScore,
                for: verdict
            ) else { return nil }

            let explanation = exactMemory == nil
                ? clean(response.content.explanation)
                : FoodMemoryStore.rememberedAssessment
            let roast = clean(response.content.roast)
            return FoodAssessment(
                verdict: verdict,
                explanation: explanation,
                roast: verdict == .healthy
                    ? nil
                    : (roast.isEmpty ? fallbackRoast(intensity: intensity) : roast),
                qualityScore: qualityScore,
                caffeineCount: FoodExposureCalculator.normalized(response.content.caffeineCount),
                sugaryItemCount: FoodExposureCalculator.normalized(response.content.sugaryItemCount)
            )
        } catch {
            AppLogger.report(error, operation: "Analyse food entry", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func summarizeDayOnDevice(
        entries: [FoodEntry],
        score: Int,
        intensity: RoastIntensity
    ) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        let band = FoodScoreBand.classify(score)
        let session = LanguageModelSession(
            instructions: dailySummaryInstructions(score: score, band: band, intensity: intensity)
        )
        do {
            let response = try await session.respond(
                to: "All food logged so far today:\n\(entryList(entries))",
                generating: GeneratedDailyFoodSummary.self
            )
            let summary = clean(response.content.summary)
            return summary.isEmpty ? nil : summary
        } catch {
            AppLogger.report(error, operation: "Summarize daily food score", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func entryInstructions(intensity: RoastIntensity) -> String {
        """
        \(drJayPersona(intensity: intensity))

        Assess one plain-language food entry using ordinary nutritional principles.
        Classify it as healthy or unhealthy. Healthy means generally balanced and nutrient-dense;
        unhealthy means dominated by highly processed, deep-fried, excessively sugary, or similarly
        poor choices. Use only the description provided. Do not invent portions, calories, medical
        conditions, allergies, or dietary restrictions.

        Assign nutrition quality from 80 through 100 when healthy, or 0 through 59 when unhealthy.
        Consider balance, nutrient density, and degree of processing within the matching range.
        Also count explicit caffeine-forward items: coffee, tea, energy drinks, caffeinated cola,
        pre-workout, or similarly intentional caffeine sources. Do not count trace caffeine in
        ordinary chocolate. Count explicit quantities; use one when a qualifying item is singular
        or its quantity is unclear.

        Separately count obvious sugary treats or sweetened drinks: cakes, chocolates, sweets,
        pastries, ice cream, desserts, or clearly sugar-sweetened beverages. Do not count fruit,
        plain milk, sauces, staple foods, naturally occurring sugar, or incidental trace sugar.
        Sugar-free and diet items count zero. Count explicit quantities; use one when unclear.

        Give one factual explanation under 100 characters. If unhealthy, write one sharp clinical roast
        under 140 characters targeting the food choice—not the user's body, weight, worth, or eating
        habits. No diagnosis, eating-disorder language, profanity, emoji, quotation marks, or hashtags.
        Never mention, quote, imitate, or claim to be any real or fictional person or character.
        If healthy, return an empty roast.

        A prompt may include an exact saved correction and semantically related corrections from
        this user. An exact saved correction is authoritative. Related corrections are examples
        only: apply one only when it is genuinely the same food, and preserve meaningful modifiers
        such as fried, grilled, sweetened, or unsweetened.
        """
    }

    @available(iOS 26.0, *)
    private static func entryPrompt(
        food: String,
        exactMemory: FoodCorrectionMemory?,
        relatedMemories: [FoodCorrectionMemory]
    ) -> String {
        var sections = ["Food eaten: \(food)"]
        if let exactMemory {
            sections.append("Exact saved user correction: \(exactMemory.verdict.label)")
        }
        if !relatedMemories.isEmpty {
            let examples = relatedMemories.map {
                "- \($0.displayText): \($0.verdict.label)"
            }.joined(separator: "\n")
            sections.append("Possibly related user corrections (examples only):\n\(examples)")
        }
        return sections.joined(separator: "\n\n")
    }

    @available(iOS 26.0, *)
    private static func dailySummaryInstructions(
        score: Int,
        band: FoodScoreBand,
        intensity: RoastIntensity
    ) -> String {
        """
        \(drJayPersona(intensity: intensity))

        The app has already calculated today's order-independent food score as \(score), classified
        as \(band.rawValue). Treat that score and classification as fixed; do not recalculate or
        contradict them. Write one sharp clinical summary under 140 characters based only on the foods
        supplied. Good must be clear clinical approval. Bad and Ugly should get an appropriately
        sharp roast. Do not repeat or begin with the score or Good, Bad, or Ugly label. Target food
        choices only—never body, weight, worth, or eating habits. Do not invent portions, calories,
        diagnoses, allergies, or dietary restrictions. No profanity,
        eating-disorder language, emoji, quotation marks, or hashtags.
        Never mention, quote, imitate, or claim to be any real or fictional person or character.
        """
    }

    @available(iOS 26.0, *)
    private static func drJayPersona(intensity: RoastIntensity) -> String {
        switch intensity {
        case .gentle:
            "You are Dr Jay: clinically precise, weary, direct, and quietly sarcastic without cruelty."
        case .playful:
            "You are Dr Jay: clinically precise, acerbic, dry, and unimpressed by excuses."
        case .spicy:
            "You are Dr Jay at maximum intensity: ruthless about choices, clinically precise, and thoroughly unimpressed."
        }
    }

    @available(iOS 26.0, *)
    private static func entryList(_ entries: [FoodEntry]) -> String {
        entries
            .sorted { $0.timestamp < $1.timestamp }
            .enumerated()
            .map { index, entry in
                let score = entry.qualityScore ?? FoodScoreCalculator.defaultScore(for: entry.verdict)
                let scoreText = score.map(String.init) ?? "unavailable"
                return "\(index + 1). [\(entry.verdict.label), quality \(scoreText)] \(entry.text)"
            }
            .joined(separator: "\n")
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func rememberedAssessment(
        for memory: FoodCorrectionMemory,
        intensity: RoastIntensity
    ) -> FoodAssessment {
        FoodAssessment(
            verdict: memory.verdict,
            explanation: FoodMemoryStore.rememberedAssessment,
            roast: memory.verdict == .unhealthy ? fallbackRoast(intensity: intensity) : nil,
            qualityScore: FoodScoreCalculator.defaultScore(for: memory.verdict) ?? 0,
            caffeineCount: nil,
            sugaryItemCount: nil
        )
    }

    private static func fallbackRoast(intensity: RoastIntensity) -> String {
        switch intensity {
        case .gentle:
            "We discussed this food already. The prognosis remains unimpressive."
        case .playful:
            "Same food, same verdict. Repetition isn't a nutritional defense."
        case .spicy:
            "You brought back the same dietary crime and expected a new diagnosis."
        }
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedFoodAssessment {
        @Guide(description: "True when the complete food entry is generally healthy; false when it is unhealthy.")
        var isHealthy: Bool

        @Guide(description: "A short factual reason for the verdict, under 100 characters.")
        var explanation: String

        @Guide(description: "For unhealthy food only: one short clinical roast under 140 characters. Empty when healthy.")
        var roast: String

        @Guide(description: "Nutrition quality: 80 through 100 if healthy, or 0 through 59 if unhealthy.")
        var qualityScore: Int

        @Guide(description: "Number of explicit caffeine-forward items. Zero when none; do not count trace caffeine in ordinary chocolate.")
        var caffeineCount: Int

        @Guide(description: "Number of obvious sugary treats or sugar-sweetened drinks. Zero for fruit, ordinary staple foods, diet, or sugar-free items.")
        var sugaryItemCount: Int
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedDailyFoodSummary {
        @Guide(description: "One sharp clinical summary of the fixed daily food score, under 140 characters.")
        var summary: String
    }
    #endif
}
