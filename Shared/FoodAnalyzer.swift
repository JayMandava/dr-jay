import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoodAssessment: Sendable {
    var verdict: FoodVerdict
    var explanation: String
    var roast: String?
}

/// Classifies a plain-language food entry locally. No food text leaves the
/// device. An unavailable model returns nil so the caller can preserve the
/// entry as explicitly unanalyzed rather than guessing.
enum FoodAnalyzer {
    static func analyze(_ food: String, intensity: RoastIntensity) async -> FoodAssessment? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await analyzeOnDevice(food, intensity: intensity)
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func analyzeOnDevice(_ food: String, intensity: RoastIntensity) async -> FoodAssessment? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        let session = LanguageModelSession(instructions: instructions(intensity: intensity))
        do {
            let response = try await session.respond(
                to: "Food eaten: \(food)",
                generating: GeneratedFoodAssessment.self
            )
            let explanation = clean(response.content.explanation)
            let roast = clean(response.content.roast)
            return FoodAssessment(
                verdict: response.content.isHealthy ? .healthy : .unhealthy,
                explanation: explanation,
                roast: response.content.isHealthy || roast.isEmpty ? nil : roast
            )
        } catch {
            AppLogger.report(error, operation: "Analyse food entry", logger: AppLogger.food)
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func instructions(intensity: RoastIntensity) -> String {
        let tone = switch intensity {
        case .gentle: "dry but restrained"
        case .playful: "sharp, clinical, and sarcastic"
        case .spicy: "ruthlessly clinical and cutting"
        }

        return """
        You assess a user's plain-language food log using ordinary nutritional principles.
        Classify the complete entry as healthy or unhealthy. Healthy means a generally balanced,
        nutrient-dense choice; unhealthy means the overall entry is dominated by highly processed,
        deep-fried, excessively sugary, or similarly poor choices. Use the description provided;
        do not invent portions, medical conditions, allergies, or dietary restrictions.

        Give one short factual explanation under 100 characters. If unhealthy, also write one
        Dr Jay roast that is \(tone), under 140 characters, and targets the food choice—not the
        user's body, weight, worth, or eating habits. No diagnosis, eating-disorder language,
        profanity, emoji, quotation marks, or hashtags. If healthy, return an empty roast.
        """
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct GeneratedFoodAssessment {
        @Guide(description: "True when the complete food entry is generally healthy; false when it is unhealthy.")
        var isHealthy: Bool

        @Guide(description: "A short factual reason for the verdict, under 100 characters.")
        var explanation: String

        @Guide(description: "For unhealthy food only: one short clinical roast under 140 characters. Empty when healthy.")
        var roast: String
    }
    #endif
}
