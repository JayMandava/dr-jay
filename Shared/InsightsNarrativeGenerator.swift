import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Swift owns the factual longitudinal interpretation. The selected model may
/// add only a roast tied to the deterministic priority.
enum InsightsNarrativeGenerator {
    static func generate(
        report: LongitudinalInsightReport,
        intensity: RoastIntensity,
        provider: BrainDumpModelProvider,
        previousCommentary: String? = nil
    ) async -> String {
        let facts = narrativeFacts(report)
        let target = roastTarget(report: report, direction: facts.direction)

        guard report.hasMinimumData else {
            return compose(
                facts: facts,
                roast: RoastStyleContract.fallback(
                    target: target,
                    intensity: intensity,
                    excluding: previousCommentary
                )
            )
        }

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
            AppLogger.report(error, operation: "Generate Gemma insights roast", logger: AppLogger.food)
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
            AppLogger.report(error, operation: "Generate insights roast", logger: AppLogger.food)
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

    private static func narrativeFacts(
        _ report: LongitudinalInsightReport
    ) -> (verdict: String, action: String, direction: InsightDirection) {
        guard report.hasMinimumData else {
            let dayWord = report.remainingBaselineDays == 1 ? "day" : "days"
            return (
                "The baseline is incomplete.",
                "Log \(report.remainingBaselineDays) more \(dayWord) before treating this as a trend.",
                .buildingBaseline
            )
        }

        let exerciseFact = report.metrics.first { $0.id == "exercise" && $0.value != "—" }
            .map { " Optional exercise log: \($0.value) session\($0.value == "1" ? "" : "s"), \($0.detail)." }
            ?? ""
        let directions = report.metrics.filter { $0.id != "exercise" }.map(\.direction)
        if directions.contains(.slipping) {
            return ("At least one core metric is slipping.\(exerciseFact)", report.recommendedAction, .slipping)
        }
        if directions.contains(.improving) {
            return ("The overall direction is improving.\(exerciseFact)", report.recommendedAction, .improving)
        }
        if report.hasComparisonBaseline {
            return ("The overall pattern is steady.\(exerciseFact)", report.recommendedAction, .steady)
        }
        return (
            "The current baseline is usable, but comparison history is still thin.",
            report.recommendedAction,
            .buildingBaseline
        )
    }

    private static func roastTarget(
        report: LongitudinalInsightReport,
        direction: InsightDirection
    ) -> RoastTarget {
        guard report.hasMinimumData else { return .baselineThin }

        let average = report.metrics.compactMap(\.score)
        let band = average.isEmpty
            ? DailySummaryBand.ugly
            : DailySummaryBand.classify(Int((average.reduce(0, +) / Double(average.count)).rounded()))

        if band == .good, direction == .improving { return .trendImproving }
        if band == .good, direction == .steady { return .allGood }

        let focus = report.primaryFocus.lowercased()
        if focus.contains("sleep") { return .sleepConsistency }
        if focus.contains("water") { return .waterConsistency }
        if focus.contains("food") { return .foodQuality }

        switch direction {
        case .improving: return .trendImproving
        case .steady: return .trendSteady
        case .slipping: return .trendSlipping
        case .buildingBaseline: return .baselineThin
        case .context: return .baselineThin
        }
    }

    private static func compose(
        facts: (verdict: String, action: String, direction: InsightDirection),
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
