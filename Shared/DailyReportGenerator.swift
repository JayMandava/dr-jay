import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Swift owns every factual sentence. The selected model may contribute only
/// a non-factual barb, which is validated before it reaches the UI.
enum DailyReportGenerator {
    static func generate(
        input: DailySummaryInput,
        result: DailySummaryResult,
        intensity: RoastIntensity,
        provider: BrainDumpModelProvider,
        previousCommentary: String? = nil
    ) async -> String {
        let facts = narrativeFacts(input: input, result: result)
        let generated: String?

        switch provider {
        case .gemma:
            generated = await generateWithGemma(
                result: result,
                intensity: intensity,
                previousCommentary: previousCommentary
            )
        case .apple:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                generated = await generateWithApple(
                    result: result,
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

        if let barb = validatedBarb(generated) {
            let commentary = compose(facts: facts, barb: barb)
            if !matches(commentary, previousCommentary) {
                return commentary
            }
        }

        return compose(
            facts: facts,
            barb: fallbackBarb(
                band: result.band,
                complete: result.isComplete,
                intensity: intensity,
                excluding: previousCommentary
            )
        )
    }

    private static func generateWithGemma(
        result: DailySummaryResult,
        intensity: RoastIntensity,
        previousCommentary: String?
    ) async -> String? {
        do {
            return try await GemmaBrainDumpService.shared.respond(
                to: [BrainDumpConversationTurn(
                    role: "user",
                    text: prompt(result: result, previousCommentary: previousCommentary)
                )],
                instructions: instructions(intensity: intensity)
            )
        } catch {
            AppLogger.report(error, operation: "Generate Gemma daily report barb", logger: AppLogger.food)
            return nil
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generateWithApple(
        result: DailySummaryResult,
        intensity: RoastIntensity,
        previousCommentary: String?
    ) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: instructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: prompt(result: result, previousCommentary: previousCommentary),
                generating: GeneratedBarb.self,
                options: GenerationOptions(temperature: 0.85, maximumResponseTokens: 80)
            )
            return response.content.barb
        } catch {
            AppLogger.report(error, operation: "Generate daily report barb", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedBarb {
        @Guide(description: "One fresh, non-factual, intensity-matched clinical barb under 180 characters. Never mention a metric, value, score, deficit, or goal.")
        var barb: String
    }
    #endif

    private static func instructions(intensity: RoastIntensity) -> String {
        let tone = switch intensity {
        case .gentle: "restrained, dry, and recognizably sarcastic without cruelty"
        case .playful: "clever, acerbic, clinical, and unmistakably playful"
        case .spicy: "cutting, ruthless about choices, and never abusive"
        }
        return """
        You write exactly one original Dr Jay barb that is \(tone).
        The app supplies a fixed status only so the barb has the right severity. Do not interpret health data.
        Never mention or imply sleep, hours, deficits, water, bottles, food, meals, steps, caffeine, sugar, goals,
        scores, percentages, values, trends, or any other metric. Use no numerals. Do not give advice or a factual
        verdict; Swift adds those separately. Target choices, never body, weight, identity, or worth. No diagnosis,
        profanity, emoji, hashtags, quotation marks, eating-disorder language, or references to real or fictional
        people. Return only one fresh sentence under 180 characters.
        """
    }

    private static func prompt(
        result: DailySummaryResult,
        previousCommentary: String?
    ) -> String {
        let status = result.isComplete ? result.band.rawValue : "Incomplete"
        let previous = previousCommentary ?? "None"
        let cue = ["case notes", "hospital paperwork", "clinical rounds", "the evidence"]
            .randomElement() ?? "case notes"
        return """
        Fixed severity status: \(status).
        Optional style cue: \(cue).
        Previous full commentary, supplied only to prevent repetition: <previous>\(previous)</previous>
        Write a different barb. Do not repeat any distinctive phrase from the previous commentary.
        """
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
        barb: String
    ) -> String {
        "\(facts.verdict) \(barb) \(facts.action)"
    }

    private static func validatedBarb(_ candidate: String?) -> String? {
        guard let candidate else { return nil }
        let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 220, !value.contains(where: \.isNumber) else { return nil }

        let forbidden: Set<String> = [
            "sleep", "slept", "hour", "hours", "deficit", "excess", "water", "bottle", "bottles",
            "food", "meal", "meals", "step", "steps", "caffeine", "sugar", "sugary", "goal", "goals",
            "score", "scores", "percent", "percentage", "metric", "metrics", "trend", "trends",
        ]
        let words = value.lowercased().split { !$0.isLetter }.map(String.init)
        guard forbidden.isDisjoint(with: words) else { return nil }
        return String(value.prefix(220))
    }

    private static func fallbackBarb(
        band: DailySummaryBand,
        complete: Bool,
        intensity: RoastIntensity,
        excluding previous: String?
    ) -> String {
        let candidates: [String]
        if !complete {
            candidates = switch intensity {
            case .gentle: [
                "Even the paperwork would like enough evidence to form an opinion.",
                "The case notes are currently more aspiration than documentation.",
            ]
            case .playful: [
                "Calling this a report is generous; it is paperwork with delusions.",
                "The chart arrived dressed as evidence and hoped nobody would ask questions.",
            ]
            case .spicy: [
                "Even your excuses arrived unfinished.",
                "The case collapsed before the evidence bothered to appear.",
            ]
            }
        } else {
            candidates = switch (band, intensity) {
            case (.good, .gentle): ["Competence suits you; try making it less surprising.", "The chart is quietly impressed, which seems to have upset it."]
            case (.good, .playful): ["Apparently the patient can follow instructions after all.", "The evidence looks competent; your excuses may file an appeal."]
            case (.good, .spicy): ["One clean case does not erase your extensive archive of avoidable nonsense.", "The chart approves, despite having every historical reason not to."]
            case (.bad, .gentle): ["The chart is unimpressed, but not yet offended.", "The evidence is recoverable, though hardly persuasive."]
            case (.bad, .playful): ["Mediocrity submitted its paperwork and listed you as the attending physician.", "The chart found the problem without needing specialist equipment."]
            case (.bad, .spicy): ["You assembled a preventable mess and presented it as routine.", "The evidence is weak, but your commitment to avoidable errors remains robust."]
            case (.ugly, .gentle): ["The chart has concerns and none of them are subtle.", "The evidence has stopped hinting and started documenting."]
            case (.ugly, .playful): ["This is less a report than a confession with formatting.", "The chart is not judging you; it simply brought overwhelming evidence."]
            case (.ugly, .spicy): ["The evidence is overwhelming and your choices mounted no defense.", "The case is indefensible; even denial declined the assignment."]
            }
        }
        return candidates.first { candidate in
            !(previous?.localizedCaseInsensitiveContains(candidate) ?? false)
        } ?? candidates[0]
    }

    private static func matches(_ value: String, _ previous: String?) -> Bool {
        guard let previous else { return false }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(previous.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }
}
