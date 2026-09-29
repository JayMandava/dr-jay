import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Swift owns the factual longitudinal interpretation. The selected model may
/// add only a validated, non-factual barb.
enum InsightsNarrativeGenerator {
    static func generate(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity,
        provider: BrainDumpModelProvider,
        previousCommentary: String? = nil
    ) async -> String {
        guard report.hasMinimumData else {
            return baselineFallback(
                report: report,
                intensity: intensity,
                excluding: previousCommentary
            )
        }

        let facts = narrativeFacts(report)
        let band = overallBand(report)
        let generated: String?

        switch provider {
        case .gemma:
            generated = await generateWithGemma(
                band: band,
                direction: facts.direction,
                intensity: intensity,
                previousCommentary: previousCommentary
            )
        case .apple:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                generated = await generateWithApple(
                    band: band,
                    direction: facts.direction,
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
                band: band,
                intensity: intensity,
                excluding: previousCommentary
            )
        )
    }

    private static func generateWithGemma(
        band: DailySummaryBand,
        direction: InsightDirection,
        intensity: RoastIntensity,
        previousCommentary: String?
    ) async -> String? {
        do {
            return try await GemmaBrainDumpService.shared.respond(
                to: [BrainDumpConversationTurn(
                    role: "user",
                    text: prompt(
                        band: band,
                        direction: direction,
                        previousCommentary: previousCommentary
                    )
                )],
                instructions: instructions(intensity: intensity)
            )
        } catch {
            AppLogger.report(error, operation: "Generate Gemma insights barb", logger: AppLogger.food)
            return nil
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generateWithApple(
        band: DailySummaryBand,
        direction: InsightDirection,
        intensity: RoastIntensity,
        previousCommentary: String?
    ) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: instructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: prompt(
                    band: band,
                    direction: direction,
                    previousCommentary: previousCommentary
                ),
                generating: GeneratedBarb.self,
                options: GenerationOptions(temperature: 0.85, maximumResponseTokens: 80)
            )
            return response.content.barb
        } catch {
            AppLogger.report(error, operation: "Generate insights barb", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedBarb {
        @Guide(description: "One fresh, non-factual, intensity-matched clinical barb under 180 characters. Never mention metrics, values, scores, deficits, goals, or trends.")
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
        The app supplies a fixed status and direction only to set severity. Do not interpret health data.
        Never mention or imply sleep, hours, deficits, water, bottles, food, meals, steps, caffeine, sugar, goals,
        scores, percentages, values, priorities, baselines, directions, trends, or any other metric. Use no numerals.
        Do not give advice or a factual verdict; Swift adds those separately. Target choices, never body, weight,
        identity, or worth. No diagnosis, profanity, emoji, hashtags, quotation marks, eating-disorder language, or
        references to real or fictional people. Return only one fresh sentence under 180 characters.
        """
    }

    private static func prompt(
        band: DailySummaryBand,
        direction: InsightDirection,
        previousCommentary: String?
    ) -> String {
        let previous = previousCommentary ?? "None"
        let cue = ["case notes", "hospital paperwork", "clinical rounds", "the evidence"]
            .randomElement() ?? "case notes"
        return """
        Fixed severity status: \(band.rawValue).
        Fixed direction category: \(direction.label).
        Optional style cue: \(cue).
        Previous full commentary, supplied only to prevent repetition: <previous>\(previous)</previous>
        Write a different barb. Do not repeat any distinctive phrase from the previous commentary.
        """
    }

    private static func narrativeFacts(
        _ report: LongitudinalInsightReport
    ) -> (verdict: String, action: String, direction: InsightDirection) {
        let directions = report.metrics.map(\.direction)
        let direction: InsightDirection
        let verdict: String
        if directions.contains(.slipping) {
            direction = .slipping
            verdict = "At least one core metric is slipping."
        } else if directions.contains(.improving) {
            direction = .improving
            verdict = "The overall direction is improving."
        } else if report.hasComparisonBaseline {
            direction = .steady
            verdict = "The overall pattern is steady."
        } else {
            direction = .buildingBaseline
            verdict = "The current baseline is usable, but comparison history is still thin."
        }
        return (verdict, report.recommendedAction, direction)
    }

    private static func compose(
        facts: (verdict: String, action: String, direction: InsightDirection),
        barb: String
    ) -> String {
        "\(facts.verdict) \(barb) \(facts.action)"
    }

    private static func overallBand(_ report: LongitudinalInsightReport) -> DailySummaryBand {
        let scores = report.metrics.compactMap(\.score)
        guard !scores.isEmpty else { return .ugly }
        return DailySummaryBand.classify(Int((scores.reduce(0, +) / Double(scores.count)).rounded()))
    }

    private static func validatedBarb(_ candidate: String?) -> String? {
        guard let candidate else { return nil }
        let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 220, !value.contains(where: \.isNumber) else { return nil }

        let forbidden: Set<String> = [
            "sleep", "slept", "hour", "hours", "deficit", "excess", "water", "bottle", "bottles",
            "food", "meal", "meals", "step", "steps", "caffeine", "sugar", "sugary", "goal", "goals",
            "score", "scores", "percent", "percentage", "metric", "metrics", "priority", "priorities",
            "baseline", "direction", "trend", "trends", "improving", "slipping", "steady",
        ]
        let words = value.lowercased().split { !$0.isLetter }.map(String.init)
        guard forbidden.isDisjoint(with: words) else { return nil }
        return String(value.prefix(220))
    }

    private static func baselineFallback(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity,
        excluding previous: String?
    ) -> String {
        let dayWord = report.remainingBaselineDays == 1 ? "day" : "days"
        let candidates = switch intensity {
        case .gentle: ["The chart is still too shy to form an opinion.", "The case notes need a little more evidence before they become persuasive."]
        case .playful: ["At present, the chart is mostly decorative.", "This is a pattern in the same way one cloud is a weather system."]
        case .spicy: ["This is a handful of alibis wearing graph paper.", "The evidence is so thin it could hide behind the chart grid."]
        }
        let barb = candidates.first { candidate in
            !(previous?.localizedCaseInsensitiveContains(candidate) ?? false)
        } ?? candidates[0]
        return "The baseline is incomplete. \(barb) Log \(report.remainingBaselineDays) more \(dayWord)."
    }

    private static func fallbackBarb(
        band: DailySummaryBand,
        intensity: RoastIntensity,
        excluding previous: String?
    ) -> String {
        let candidates: [String] = switch (band, intensity) {
        case (.good, .gentle): ["Competence is visible; consistency would make it convincing.", "The chart is quietly impressed, which seems to have upset it."]
        case (.good, .playful): ["The evidence looks good, which is inconvenient for your excuses.", "Apparently the patient can follow instructions after all."]
        case (.good, .spicy): ["One clean case does not erase your archive of avoidable nonsense.", "The chart approves, despite having every historical reason not to."]
        case (.bad, .gentle): ["The evidence is recoverable, though hardly persuasive.", "The chart is unimpressed, but not yet offended."]
        case (.bad, .playful): ["The chart found the weak point without specialist equipment.", "Mediocrity submitted its paperwork and listed you as the attending physician."]
        case (.bad, .spicy): ["The recurring problem has returned without a redeeming arc.", "The evidence is weak, but your commitment to avoidable errors remains robust."]
        case (.ugly, .gentle): ["The evidence has stopped hinting and started documenting.", "The chart has concerns and none of them are subtle."]
        case (.ugly, .playful): ["The chart is not judging you; it simply brought overwhelming evidence.", "This is less an analysis than a confession with formatting."]
        case (.ugly, .spicy): ["The case is indefensible; even denial declined the assignment.", "The evidence is overwhelming and your choices mounted no defense."]
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
