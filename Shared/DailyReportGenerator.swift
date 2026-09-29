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
        intensity: RoastIntensity,
        provider: BrainDumpModelProvider
    ) async -> String {
        if provider == .gemma,
           let generated = await generateWithGemma(input: input, result: result, intensity: intensity) {
            return generated
        }

        #if canImport(FoundationModels)
        if provider == .apple,
           #available(iOS 26.0, *),
           let generated = await generateOnDevice(input: input, result: result, intensity: intensity) {
            return generated
        }
        #endif
        return fallback(input: input, result: result, intensity: intensity)
    }

    private static func generateWithGemma(
        input: DailySummaryInput,
        result: DailySummaryResult,
        intensity: RoastIntensity
    ) async -> String? {
        do {
            let response = try await GemmaBrainDumpService.shared.respond(
                to: [BrainDumpConversationTurn(role: "user", text: prompt(input: input, result: result))],
                instructions: instructions(intensity: intensity)
            )
            return cleaned(response)
        } catch {
            AppLogger.report(error, operation: "Generate Gemma daily report commentary", logger: AppLogger.food)
            return nil
        }
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
            return joined(
                response.content.verdict,
                response.content.barb,
                response.content.action
            )
        } catch {
            AppLogger.report(error, operation: "Generate daily report commentary", logger: AppLogger.food)
            return nil
        }
    }

    private static func instructions(intensity: RoastIntensity) -> String {
        let tone: String
        switch intensity {
        case .gentle:
            tone = "Gentle: use a restrained, dry barb. It must still be recognizably sarcastic, never cruel."
        case .playful:
            tone = "Playful: use an unmistakable, clever clinical roast with dry sarcasm."
        case .spicy:
            tone = "Spicy: use a cutting, ruthless clinical roast while attacking choices only."
        }
        return """
        You are Dr Jay, an original, clinically precise wellness commentator. \(tone)
        React to an already-calculated daily wellness verdict in exactly three concise sentences under 500 characters:
        (1) a clinical verdict, (2) a mandatory intensity-matched barb, and (3) one practical next action.
        A merely neutral second sentence is invalid. Good gets clear approval while roasting complacency; Bad gets a
        pointed roast of the weakest factor; Ugly gets the sharpest roast of the day's choices. An incomplete chart
        gets roasted for missing core data instead of receiving a normal verdict reaction.
        Treat the supplied score, metric values, weights, and completeness as fixed facts. Never recalculate,
        contradict, diagnose illness, or invent missing data. Steps have deliberately low influence because
        a phone may not capture all movement. Do not repeat the score, verdict, weights, or list of metrics—the UI
        already shows them. Mention at most one specific metric, only when it explains the diagnosis. Target choices,
        never body, weight, or worth. No emoji, hashtags, quotation marks, profanity, or eating-disorder language.
        Never mention, quote, imitate, or claim to be any real or fictional person or character.
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
        Write a fresh Dr Jay reaction, not a restatement of this chart.
        """
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedDailyReport {
        @Guide(description: "One concise clinical verdict sentence based on the fixed status.")
        var verdict: String

        @Guide(description: "One mandatory dry, intensity-matched barb aimed only at the choices. It must not be neutral advice.")
        var barb: String

        @Guide(description: "One concise, practical next-action sentence.")
        var action: String
    }
    #endif

    private static func fallback(
        input: DailySummaryInput,
        result: DailySummaryResult,
        intensity: RoastIntensity
    ) -> String {
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
            let barb = switch intensity {
            case .gentle: "Even your chart would like enough information to form an opinion."
            case .playful: "Calling this a report is generous; it is paperwork with delusions."
            case .spicy: "This chart is so incomplete even the excuses arrived unfinished."
            }
            return "The report is incomplete. \(barb) Log the missing sleep or food data."
        }

        let weakness = observations.first ?? "nothing obvious"
        let barb: String = switch (result.band, intensity) {
        case (.good, .gentle): "Competence suits you; try making it less surprising."
        case (.good, .playful): "Annoyingly competent—apparently the patient can follow instructions."
        case (.good, .spicy): "A good day does not erase the extensive case history of avoidable nonsense."
        case (.bad, .gentle): "The chart is unimpressed, but at least it has seen worse."
        case (.bad, .playful): "Mediocrity has submitted its paperwork and listed you as the attending physician."
        case (.bad, .spicy): "You assembled a preventable mess and presented it as a normal day."
        case (.ugly, .gentle): "The chart has concerns and, unusually, none of them are subtle."
        case (.ugly, .playful): "This is less a wellness report than a confession with percentages."
        case (.ugly, .spicy): "The evidence is overwhelming; your choices barely mounted a defense."
        }
        let verdict = switch result.band {
        case .good: "The day lands in good territory."
        case .bad: "The day is salvageable, not successful."
        case .ugly: "The day is clinically ugly."
        }
        return "\(verdict) \(barb) Address this first tomorrow: \(weakness)."
    }

    private static func joined(_ parts: String...) -> String? {
        let value = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return cleaned(value)
    }

    private static func cleaned(_ value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : String(value.prefix(600))
    }
}
