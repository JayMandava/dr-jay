import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoodAssessment: Sendable {
    var verdict: FoodVerdict
    var explanation: String
    var roast: String?
}

struct DailyFoodAssessment: Sendable {
    var score: Int
    var summary: String
}

struct FoodLogAssessment: Sendable {
    var entry: FoodAssessment
    var day: DailyFoodAssessment
}

/// Classifies a plain-language food entry locally. No food text leaves the
/// device. An unavailable model returns nil so the caller can preserve the
/// entry as explicitly unanalyzed rather than guessing.
enum FoodAnalyzer {
    static func analyze(
        _ food: String,
        dayEntries: [FoodEntry],
        intensity: RoastIntensity
    ) async -> FoodLogAssessment? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await analyzeOnDevice(food, dayEntries: dayEntries, intensity: intensity)
        }
        #endif
        return nil
    }

    static func scoreDay(
        entries: [FoodEntry],
        intensity: RoastIntensity
    ) async -> DailyFoodAssessment? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await scoreDayOnDevice(entries: entries, intensity: intensity)
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func analyzeOnDevice(
        _ food: String,
        dayEntries: [FoodEntry],
        intensity: RoastIntensity
    ) async -> FoodLogAssessment? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        let session = LanguageModelSession(instructions: entryInstructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: """
                Newly logged food: \(food)

                All food logged so far today:
                \(entryList(dayEntries))
                """,
                generating: GeneratedFoodAssessment.self
            )
            let explanation = clean(response.content.explanation)
            let roast = clean(response.content.roast)
            return FoodLogAssessment(
                entry: FoodAssessment(
                    verdict: response.content.isHealthy ? .healthy : .unhealthy,
                    explanation: explanation,
                    roast: response.content.isHealthy || roast.isEmpty ? nil : roast
                ),
                day: DailyFoodAssessment(
                    score: min(100, max(0, response.content.dailyScore)),
                    summary: clean(response.content.dailySummary)
                )
            )
        } catch {
            AppLogger.report(error, operation: "Analyse food entry and daily score", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func scoreDayOnDevice(
        entries: [FoodEntry],
        intensity: RoastIntensity
    ) async -> DailyFoodAssessment? {
        guard !entries.isEmpty,
              case .available = SystemLanguageModel.default.availability
        else { return nil }

        let session = LanguageModelSession(instructions: dailyScoreInstructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: "All food logged so far today:\n\(entryList(entries))",
                generating: GeneratedDailyFoodScore.self
            )
            return DailyFoodAssessment(
                score: min(100, max(0, response.content.score)),
                summary: clean(response.content.summary)
            )
        } catch {
            AppLogger.report(error, operation: "Recompute daily food score", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func entryInstructions(intensity: RoastIntensity) -> String {
        """
        \(housePersona(intensity: intensity))

        You assess a user's plain-language food log using ordinary nutritional principles.
        Classify the complete entry as healthy or unhealthy. Healthy means a generally balanced,
        nutrient-dense choice; unhealthy means the overall entry is dominated by highly processed,
        deep-fried, excessively sugary, or similarly poor choices. Use the description provided;
        do not invent portions, medical conditions, allergies, or dietary restrictions.

        Give one short factual explanation under 100 characters. If unhealthy, also write one
        House-style roast under 140 characters that targets the food choice—not the
        user's body, weight, worth, or eating habits. No diagnosis, eating-disorder language,
        profanity, emoji, quotation marks, or hashtags. If healthy, return an empty roast.

        Also score all foods logged today from 0 to 100 using this exact rubric:
        80–100 is Good, 60–79 is Bad, and 0–59 is Ugly. Write one House-style daily summary
        under 140 characters. A Good score must read as clean clinical approval. Bad and Ugly
        should receive an appropriately sharp roast. Judge only the food provided and do not
        pretend this is a calorie count or medical nutrition assessment.
        """
    }

    @available(iOS 26.0, *)
    private static func dailyScoreInstructions(intensity: RoastIntensity) -> String {
        """
        \(housePersona(intensity: intensity))

        Score the complete food log from 0 to 100 using ordinary nutritional principles.
        Use this exact rubric: 80–100 is Good, 60–79 is Bad, and 0–59 is Ugly.
        Treat any supplied Healthy or Unhealthy verdict as authoritative; assess Unanalyzed
        entries yourself. Judge only what was logged. Do not invent portions, calories,
        conditions, allergies, or dietary restrictions.

        Write one House-style summary under 140 characters. Good must be unambiguously positive
        clinical approval. Bad and Ugly should be an appropriately sharp roast. Target food
        choices only—never body, weight, worth, or eating habits. No diagnosis, profanity,
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
                "\(index + 1). [\(entry.verdict.label)] \(entry.text)"
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

        @Guide(description: "A whole number from 0 through 100 scoring all food logged today.")
        var dailyScore: Int

        @Guide(description: "One House-style summary of today's food score, under 140 characters.")
        var dailySummary: String
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedDailyFoodScore {
        @Guide(description: "A whole number from 0 through 100 scoring all food logged today.")
        var score: Int

        @Guide(description: "One House-style summary of today's food score, under 140 characters.")
        var summary: String
    }
    #endif
}
