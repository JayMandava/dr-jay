import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum InsightsNarrativeGenerator {
    static func generate(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity
    ) async -> String {
        guard report.hasMinimumData else { return fallback(report: report) }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let generated = await generateOnDevice(report: report, intensity: intensity) {
            return generated
        }
        #endif
        return fallback(report: report)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generateOnDevice(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity
    ) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: instructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: report.factSummary,
                generating: GeneratedInsight.self
            )
            let commentary = response.content.commentary
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return commentary.isEmpty ? nil : String(commentary.prefix(600))
        } catch {
            AppLogger.report(error, operation: "Generate longitudinal insights", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func instructions(intensity: RoastIntensity) -> String {
        let tone: String
        switch intensity {
        case .gentle: tone = "clinically direct with restrained dry sarcasm"
        case .playful: tone = "sharp, dry, acerbic, and playful"
        case .spicy: tone = "ruthlessly concise and thoroughly unimpressed"
        }
        return """
        You are Dr Jay, an original on-device wellness commentator who is \(tone).
        Interpret a deterministic multi-day wellness analysis in 2 or 3 sentences under 500 characters.
        Lead with the overall direction, identify the fixed priority, and end with the supplied next action.
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
        @Guide(description: "A 2 or 3 sentence longitudinal interpretation under 500 characters.")
        var commentary: String
    }
    #endif

    private static func fallback(report: LongitudinalInsightReport) -> String {
        guard report.hasMinimumData else {
            let dayWord = report.remainingBaselineDays == 1 ? "day" : "days"
            return "The chart is still pretending to be a trend. Log \(report.remainingBaselineDays) more \(dayWord), then Dr Jay can distinguish a pattern from a coincidence."
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
        return "\(direction) The priority is \(report.primaryFocus.lowercased()). \(report.recommendedAction)"
    }
}
