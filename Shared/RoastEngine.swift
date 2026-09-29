import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct NudgeContext: Sendable {
    var kind: CheckKind
    var window: CheckInWindow
    var met: Bool
    var detail: String
    var value: Double
    var goal: Double
    var streak: Int
    var intensity: RoastIntensity

    var isOversleeping: Bool {
        kind == .sleep && value > AppConfig.sleepGoalMaxHours
    }
}

struct NudgeMessage: Sendable, Codable {
    var text: String
}

/// Swift freezes the factual check-in detail. The model writes only a roast
/// for the matching verified target, preventing it from changing the result.
enum RoastEngine {
    static func generate(_ context: NudgeContext) async -> NudgeMessage {
        let target = roastTarget(context)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let generated = await generateOnDevice(target: target, context: context),
           let roast = RoastStyleContract.validated(
               generated,
               target: target,
               intensity: context.intensity
           ) {
            return NudgeMessage(text: compose(detail: context.detail, roast: roast))
        }
        #endif

        return NudgeMessage(
            text: compose(
                detail: context.detail,
                roast: RoastStyleContract.fallback(target: target, intensity: context.intensity)
            )
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generateOnDevice(
        target: RoastTarget,
        context: NudgeContext
    ) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(
            instructions: RoastStyleContract.modelInstructions(
                target: target,
                intensity: context.intensity
            )
        )
        do {
            let response = try await session.respond(
                to: "Write the target-bound roast now. The app will add all factual values separately.",
                generating: GeneratedRoast.self,
                options: GenerationOptions(temperature: 0.9, maximumResponseTokens: 70)
            )
            return response.content.roast
        } catch {
            return nil
        }
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedRoast {
        @Guide(description: "One roast sentence obeying the supplied target and intensity contract.")
        var roast: String
    }
    #endif

    private static func roastTarget(_ context: NudgeContext) -> RoastTarget {
        switch context.kind {
        case .sleep:
            if context.isOversleeping { return .sleepOver }
            return context.met ? .sleepMet : .sleepUnder
        case .water:
            return context.met ? .waterMet : .waterIncomplete
        }
    }

    private static func compose(detail: String, roast: String) -> String {
        let detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        return "\(detail). \(roast)"
    }
}
