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
        React to an already-calculated daily wellness verdict in 2 or 3 concise sentences under 450 characters.
        The verdict controls the response: Good gets clear clinical approval with one dry barb; Bad gets a
        pointed roast of the weakest major factor; Ugly gets a sharper House-style diagnosis of the day's choices.
        An incomplete chart gets roasted for missing core data instead of receiving a normal verdict reaction.
        Interpret the result and give one practical next action.
        Treat the supplied score, metric values, weights, and completeness as fixed facts. Never recalculate,
        contradict, diagnose illness, or invent missing data. Steps have deliberately low influence because
        a phone may not capture all movement. Do not repeat the score, verdict, weights, or list of metrics—the UI
        already shows them. Mention at most one specific metric, only when it explains the diagnosis. Target choices,
        never body, weight, or worth. No emoji, hashtags, quotation marks, profanity, or eating-disorder language.
        """
    }

    @available(iOS 26.0, *)
    private static func prompt(input: DailySummaryInput, result: DailySummaryResult) -> String {
        """
        Fixed overall score: \(result.score)/100.
        Fixed overall verdict: \(result.band.rawValue).
        Report complete: \(result.isComplete ? "yes" : "no; missing core data must be acknowledged").
        Values: \(result.detail).
        Calculation: food 35%, sleep 30%, water 30%, steps 5%. Missing metrics are excluded and the available
        weights are proportionally normalized, so absent step data never lowers the score.
        Write a fresh House-style reaction, not a restatement of this chart.
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

        guard result.isComplete else {
            return "An incomplete chart is not a wellness report; it is paperwork with delusions. Log the missing sleep or food data, then ask for a diagnosis."
        }

        let weakness = observations.first ?? "nothing obvious"
        switch result.band {
        case .good:
            let caveat = observations.first.map { "One caveat: \($0)." }
                ?? "No obvious lesion today."
            return "Annoyingly competent work. \(caveat) Preserve what worked instead of treating basic consistency like a special occasion."
        case .bad:
            return "Salvageable, which is the nicest diagnosis available. The weak point is simple: \(weakness). Fix that first tomorrow."
        case .ugly:
            return "The chart is less a report than a confession. Start with the obvious lesion—\(weakness)—and give tomorrow fewer symptoms to explain."
        }
    }
}
