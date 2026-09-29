import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Swift owns every factual sentence. The selected model may contribute only
/// a target-bound roast, which is validated before it reaches the UI.
enum DailyReportGenerator {
    static func generate(
        input: DailySummaryInput,
        result: DailySummaryResult,
        intensity: RoastIntensity,
        provider: BrainDumpModelProvider,
        previousCommentary: String? = nil
    ) async -> String {
        let facts = narrativeFacts(input: input, result: result)
        let target = roastTarget(input: input, result: result)
        let generated: String?

        switch provider {
        case .gemma:
            generated = await generateWithGemma(
                target: target,
                intensity: intensity,
                previousCommentary: previousCommentary
            )
        case .apple:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                generated = await generateWithApple(
                    target: target,
                    intensity: intensity,
                    previousCommentary: previousCommentary
                )
            } else {
                generated = nil
            }
            #else
            generated = nil
            #endif
        }

        if let roast = RoastStyleContract.validated(
            generated,
            target: target,
            intensity: intensity
        ) {
            let commentary = compose(facts: facts, roast: roast)
            if !matches(commentary, previousCommentary) {
                return commentary
            }
        }

        return compose(
            facts: facts,
            roast: RoastStyleContract.fallback(
                target: target,
                intensity: intensity,
                excluding: previousCommentary
            )
        )
    }

    private static func generateWithGemma(
        target: RoastTarget,
        intensity: RoastIntensity,
        previousCommentary: String?
    ) async -> String? {
        do {
            return try await GemmaBrainDumpService.shared.respond(
                to: [BrainDumpConversationTurn(
                    role: "user",
                    text: variationPrompt(previousCommentary: previousCommentary)
                )],
                instructions: RoastStyleContract.modelInstructions(
                    target: target,
                    intensity: intensity
                )
            )
        } catch {
            AppLogger.report(error, operation: "Generate Gemma daily report roast", logger: AppLogger.food)
            return nil
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generateWithApple(
        target: RoastTarget,
        intensity: RoastIntensity,
        previousCommentary: String?
    ) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(
            instructions: RoastStyleContract.modelInstructions(
                target: target,
                intensity: intensity
            )
        )
        do {
            let response = try await session.respond(
                to: variationPrompt(previousCommentary: previousCommentary),
                generating: GeneratedRoast.self,
                options: GenerationOptions(temperature: 0.9, maximumResponseTokens: 80)
            )
            return response.content.roast
        } catch {
            AppLogger.report(error, operation: "Generate daily report roast", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedRoast {
        @Guide(description: "One fresh roast sentence obeying the supplied target and intensity contract.")
        var roast: String
    }
    #endif

    private static func variationPrompt(previousCommentary: String?) -> String {
        let previous = previousCommentary ?? "None"
        let cue = ["bureaucratic failure", "clinical absurdity", "failed competence", "case-file embarrassment"]
            .randomElement() ?? "clinical absurdity"
        return """
        Optional comic angle: \(cue).
        Previous full commentary, supplied only to prevent repetition: <previous>\(previous)</previous>
        Write a different roast without reusing its distinctive wording.
        """
    }

    private static func roastTarget(
        input: DailySummaryInput,
        result: DailySummaryResult
    ) -> RoastTarget {
        guard result.isComplete else { return .missingData }
        if let food = input.foodScore, food < 60 { return .foodUgly }
        if let food = input.foodScore, food < 80 { return .foodBad }
        if let sleep = input.sleepHours, sleep < AppConfig.sleepGoalHours { return .sleepUnder }
        if let sleep = input.sleepHours, sleep > AppConfig.sleepGoalMaxHours { return .sleepOver }
        if input.waterBottlesLogged < max(1, input.waterGoalBottles) { return .waterIncomplete }
        return .allGood
    }

    private static func narrativeFacts(
        input: DailySummaryInput,
        result: DailySummaryResult
    ) -> (verdict: String, action: String) {
        guard result.isComplete else {
            return (
                "The report is incomplete.",
                "Log the missing sleep or food data before asking for another reading."
            )
        }

        let verdict = switch result.band {
        case .good: "The day lands in good territory."
        case .bad: "The day is salvageable, not successful."
        case .ugly: "The day lands firmly in ugly territory."
        }

        let action: String
        if let food = input.foodScore, food < 80 {
            action = "Improve the next meal instead of trying to rescue the whole day."
        } else if let sleep = input.sleepHours, sleep < AppConfig.sleepGoalHours {
            action = "Protect a sleep window of at least 6 hours tonight."
        } else if let sleep = input.sleepHours, sleep > AppConfig.sleepGoalMaxHours {
            action = "Keep tonight’s sleep within the 6–9 hour range."
        } else if input.waterBottlesLogged < max(1, input.waterGoalBottles) {
            action = "Finish the full water goal before the night check-in."
        } else {
            action = "Repeat what worked tomorrow instead of treating consistency as optional."
        }
        return (verdict, action)
    }

    private static func compose(
        facts: (verdict: String, action: String),
        roast: String
    ) -> String {
        "\(facts.verdict) \(roast)\n\nPrescription: \(facts.action)"
    }

    private static func matches(_ value: String, _ previous: String?) -> Bool {
        guard let previous else { return false }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(previous.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }
}
