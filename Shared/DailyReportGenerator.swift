import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Adds Dr Jay's narrative to the calculator's fixed result. The model never
/// chooses or alters the score; unavailable Apple Intelligence falls back to
/// an equally transparent local explanation.
enum DailyReportGenerator {
    static func generate(
        input: DailySummaryInput,
        result: DailySummaryResult,
        intensity: RoastIntensity
    ) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let generated = await generateOnDevice(input: input, result: result, intensity: intensity) {
            return generated
        }
        #endif
        return fallback(input: input, result: result)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generateOnDevice(
        input: DailySummaryInput,
        result: DailySummaryResult,
        intensity: RoastIntensity
    ) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: instructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: prompt(input: input, result: result),
                generating: GeneratedDailyReport.self
            )
            let commentary = response.content.commentary
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return commentary.isEmpty ? nil : commentary
        } catch {
            AppLogger.report(error, operation: "Generate daily report commentary", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func instructions(intensity: RoastIntensity) -> String {
        let tone: String
        switch intensity {
        case .gentle:
            tone = "clinically direct with restrained, dry sarcasm"
        case .playful:
            tone = "sharp, dry, and unmistakably House-like"
        case .spicy:
            tone = "ruthlessly clinical and thoroughly unimpressed"
        }
        return """
        You are Dr Jay, a brilliant diagnostician who is \(tone).
        Explain an already-calculated daily wellness report in 2 or 3 concise sentences under 450 characters.
        State what most helped the score, what most hurt it, and one practical next action.
        Treat the supplied score, metric values, weights, and completeness as fixed facts. Never recalculate,
        contradict, diagnose illness, or invent missing data. Steps have deliberately low influence because
        a phone may not capture all movement. Target choices, never body, weight, or worth. No emoji, hashtags,
        quotation marks, profanity, or eating-disorder language.
        """
    }

    @available(iOS 26.0, *)
    private static func prompt(input: DailySummaryInput, result: DailySummaryResult) -> String {
        """
        Fixed overall score: \(result.score)/100.
        Report complete: \(result.isComplete ? "yes" : "no; missing core data must be acknowledged").
        Values: \(result.detail).
        Calculation: food 35%, sleep 30%, water 30%, steps 5%. Missing metrics are excluded and the available
        weights are proportionally normalized, so absent step data never lowers the score.
        Write the report commentary now.
        """
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedDailyReport {
        @Guide(description: "A 2 or 3 sentence explanation of the fixed report, under 450 characters.")
        var commentary: String
    }
    #endif

    private static func fallback(input: DailySummaryInput, result: DailySummaryResult) -> String {
        var observations: [String] = []
        if let food = input.foodScore, food < 80 {
            observations.append("food carries the most weight and needs the most attention")
        }
        if let sleep = input.sleepHours,
           !(AppConfig.sleepGoalHours...AppConfig.sleepGoalMaxHours).contains(sleep) {
            observations.append("sleep is outside the 6–9 hour range")
        }
        if input.waterBottlesLogged < max(1, input.waterGoalBottles) {
            observations.append("water is still below the full-day goal")
        }

        let diagnosis = observations.first ?? "the core metrics are holding their end of the bargain"
        let completeness = result.isComplete
            ? "The chart is complete."
            : "The chart is incomplete, so missing sleep or food was excluded rather than guessed."
        return "\(result.score)/100: \(diagnosis.capitalized). \(completeness) Food counts 35%, sleep and water 30% each, and steps just 5%."
    }
}
