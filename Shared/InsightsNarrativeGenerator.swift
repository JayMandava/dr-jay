import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum InsightsNarrativeGenerator {
    static func generate(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity,
        provider: BrainDumpModelProvider
    ) async -> String {
        guard report.hasMinimumData else { return fallback(report: report, intensity: intensity) }

        if provider == .gemma,
           let generated = await generateWithGemma(report: report, intensity: intensity) {
            return generated
        }

        #if canImport(FoundationModels)
        if provider == .apple,
           #available(iOS 26.0, *),
           let generated = await generateOnDevice(report: report, intensity: intensity) {
            return generated
        }
        #endif
        return fallback(report: report, intensity: intensity)
    }

    private static func generateWithGemma(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity
    ) async -> String? {
        do {
            let response = try await GemmaBrainDumpService.shared.respond(
                to: [BrainDumpConversationTurn(role: "user", text: report.factSummary)],
                instructions: instructions(report: report, intensity: intensity)
            )
            return cleaned(response)
        } catch {
            AppLogger.report(error, operation: "Generate Gemma longitudinal insights", logger: AppLogger.food)
            return nil
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generateOnDevice(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity
    ) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: instructions(report: report, intensity: intensity))
        do {
            let response = try await session.respond(
                to: report.factSummary,
                generating: GeneratedInsight.self
            )
            return joined(
                response.content.verdict,
                response.content.barb,
                response.content.action
            )
        } catch {
            AppLogger.report(error, operation: "Generate longitudinal insights", logger: AppLogger.food)
            return nil
        }
    }

    private static func instructions(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity
    ) -> String {
        let tone: String
        switch intensity {
        case .gentle: tone = "Gentle: use a restrained but unmistakably dry barb without cruelty."
        case .playful: tone = "Playful: use one clever, acerbic clinical roast."
        case .spicy: tone = "Spicy: use one cutting, ruthless roast aimed only at the choices."
        }
        let band = overallBand(report)
        return """
        You are Dr Jay, an original on-device wellness commentator. \(tone)
        The deterministic overall status is \(band.rawValue). Interpret the supplied multi-day analysis in exactly
        three concise sentences under 500 characters: (1) the direction and status, (2) a mandatory intensity-matched
        barb, and (3) the supplied next action. A neutral second sentence is invalid. Good gets clinical approval while
        roasting complacency; Bad gets a pointed roast of the fixed priority; Ugly gets the sharpest roast of it.
        Treat every supplied number, direction, priority, and relationship statement as fixed. Never recalculate,
        invent missing data, imply causation, diagnose illness, or offer medication or treatment advice. If no
        comparison baseline exists, say so plainly instead of claiming improvement or decline. Do not mention steps;
        they are intentionally absent from history. Target choices, never body, weight, identity, or worth.
        Never mention, quote, imitate, or claim to be any real or fictional person or character.
        No emoji, hashtags, quotation marks, profanity, or eating-disorder language.
        """
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedInsight {
        @Guide(description: "One concise sentence stating the supplied direction and deterministic status.")
        var verdict: String

        @Guide(description: "One mandatory dry, intensity-matched barb aimed only at the choices. It must not be neutral advice.")
        var barb: String

        @Guide(description: "One concise sentence using the supplied fixed next action.")
        var action: String
    }
    #endif

    private static func fallback(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity
    ) -> String {
        guard report.hasMinimumData else {
            let dayWord = report.remainingBaselineDays == 1 ? "day" : "days"
            let barb = switch intensity {
            case .gentle: "The chart is still too shy to form an opinion."
            case .playful: "At present, the chart is mostly decorative."
            case .spicy: "This is not a trend; it is a handful of alibis wearing graph paper."
            }
            return "The baseline is incomplete. \(barb) Log \(report.remainingBaselineDays) more \(dayWord)."
        }

        let direction: String
        let directions = report.metrics.map(\.direction)
        if directions.contains(.slipping) {
            direction = "At least one core metric is slipping."
        } else if directions.contains(.improving) {
            direction = "The overall direction is improving."
        } else if report.hasComparisonBaseline {
            direction = "The overall pattern is steady."
        } else {
            direction = "The current baseline is usable, but comparison history is still thin."
        }
        let band = overallBand(report)
        let barb: String = switch (band, intensity) {
        case (.good, .gentle): "Competence is visible; consistency would make it convincing."
        case (.good, .playful): "The chart looks good, which is an inconvenient blow to your excuses."
        case (.good, .spicy): "A strong window does not grant immunity from the next preventable disaster."
        case (.bad, .gentle): "The pattern is recoverable, though hardly persuasive."
        case (.bad, .playful): "The chart has located the weak point; subtlety was apparently unnecessary."
        case (.bad, .spicy): "The weak point has become a recurring character, and it still has no redeeming arc."
        case (.ugly, .gentle): "The pattern needs attention; it has stopped hinting."
        case (.ugly, .playful): "The chart is not judging you; it simply brought overwhelming evidence."
        case (.ugly, .spicy): "This pattern is less a wellness trend than a documented failure to intervene."
        }
        return "\(direction) \(barb) \(report.recommendedAction)"
    }

    private static func overallBand(_ report: LongitudinalInsightReport) -> DailySummaryBand {
        let scores = report.metrics.compactMap(\.score)
        guard !scores.isEmpty else { return .ugly }
        let average = scores.reduce(0, +) / Double(scores.count)
        return DailySummaryBand.classify(Int(average.rounded()))
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
