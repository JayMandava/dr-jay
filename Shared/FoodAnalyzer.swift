import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoodAssessment: Sendable {
    var verdict: FoodVerdict
    var explanation: String
    var roast: String?
    var qualityScore: Int
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

/// Classifies a plain-language food entry locally. No food text leaves the
/// device. An unavailable model returns nil so the caller can preserve the
/// entry as explicitly unanalyzed rather than guessing.
enum FoodAnalyzer {
    static func analyze(_ food: String, intensity: RoastIntensity) async -> FoodAssessment? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await analyzeOnDevice(food, intensity: intensity)
        }
        #endif
        return nil
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
        intensity: RoastIntensity
    ) async -> FoodAssessment? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        let session = LanguageModelSession(instructions: entryInstructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: "Food eaten: \(food)",
                generating: GeneratedFoodAssessment.self
            )
            let verdict: FoodVerdict = response.content.isHealthy ? .healthy : .unhealthy
            guard let qualityScore = FoodScoreCalculator.normalized(
                response.content.qualityScore,
                for: verdict
            ) else { return nil }

            let explanation = clean(response.content.explanation)
            let roast = clean(response.content.roast)
            return FoodAssessment(
                verdict: verdict,
                explanation: explanation,
                roast: verdict == .healthy || roast.isEmpty ? nil : roast,
                qualityScore: qualityScore
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
        \(housePersona(intensity: intensity))

        Assess one plain-language food entry using ordinary nutritional principles.
        Classify it as healthy or unhealthy. Healthy means generally balanced and nutrient-dense;
        unhealthy means dominated by highly processed, deep-fried, excessively sugary, or similarly
        poor choices. Use only the description provided. Do not invent portions, calories, medical
        conditions, allergies, or dietary restrictions.

        Assign nutrition quality from 80 through 100 when healthy, or 0 through 59 when unhealthy.
        Consider balance, nutrient density, and degree of processing within the matching range.
        Give one factual explanation under 100 characters. If unhealthy, write one House-style roast
        under 140 characters targeting the food choice—not the user's body, weight, worth, or eating
        habits. No diagnosis, eating-disorder language, profanity, emoji, quotation marks, or hashtags.
        If healthy, return an empty roast.
        """
    }

    @available(iOS 26.0, *)
    private static func dailySummaryInstructions(
        score: Int,
        band: FoodScoreBand,
        intensity: RoastIntensity
    ) -> String {
        """
        \(housePersona(intensity: intensity))

        The app has already calculated today's order-independent food score as \(score), classified
        as \(band.rawValue). Treat that score and classification as fixed; do not recalculate or
        contradict them. Write one House-style summary under 140 characters based only on the foods
        supplied. Good must be clear clinical approval. Bad and Ugly should get an appropriately
        sharp roast. Do not repeat or begin with the score or Good, Bad, or Ugly label. Target food
        choices only—never body, weight, worth, or eating habits. Do not invent portions, calories,
        diagnoses, allergies, or dietary restrictions. No profanity,
        eating-disorder language, emoji, quotation marks, or hashtags.
        """
    }

    @available(iOS 26.0, *)
    private static func housePersona(intensity: RoastIntensity) -> String {
        switch intensity {
        case .gentle:
            "You are Dr. Gregory House, dialed down: brilliant, weary, clinically direct, and quietly sarcastic without cruelty."
        case .playful:
            "You are Dr. Gregory House: a brilliant, misanthropic diagnostician with sharp dry wit and no patience for excuses."
        case .spicy:
            "You are Dr. Gregory House at his most insufferable: brilliant, ruthless, clinical, and thoroughly unimpressed."
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
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedDailyFoodSummary {
        @Guide(description: "One House-style summary of the fixed daily food score, under 140 characters.")
        var summary: String
    }
    #endif
}
