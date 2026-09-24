import Foundation

enum BrainDumpSafetyRoute: Equatable {
    case conversation
    case prohibitedAdvice
    case vulnerable
    case immediateRisk
}

/// A deterministic first line of defence. The language model only receives
/// ordinary conversation; high-risk and prohibited requests never depend on
/// model judgment or model availability.
enum BrainDumpSafetyRouter {
    static func route(_ text: String) -> BrainDumpSafetyRoute {
        let normalized = normalize(text)

        if containsAny(immediateRiskPhrases, in: normalized) {
            return .immediateRisk
        }
        if containsAny(vulnerablePhrases, in: normalized) {
            return .vulnerable
        }
        if containsAny(prohibitedAdvicePhrases, in: normalized) {
            return .prohibitedAdvice
        }
        return .conversation
    }

    private static func normalize(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let words = folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return " " + words.joined(separator: " ") + " "
    }

    private static func containsAny(_ phrases: [String], in text: String) -> Bool {
        phrases.contains { text.contains(" \($0) ") }
    }

    private static let immediateRiskPhrases = [
        "kill myself", "end my life", "take my life", "hurt myself", "harm myself",
        "want to die", "do not want to live", "dont want to live", "better off dead",
        "suicidal", "suicide", "kill them", "kill him", "kill her", "hurt someone",
        "harm someone"
    ]

    private static let vulnerablePhrases = [
        "i hate myself", "i am worthless", "im worthless", "no one would miss me",
        "everyone is watching me", "they are watching me", "someone is watching me",
        "i am being followed", "im being followed", "they are tracking me",
        "cameras in the walls", "voices are telling me", "i am hearing voices",
        "im hearing voices"
    ]

    private static let prohibitedAdvicePhrases = [
        "diagnose me", "what diagnosis", "what medication", "which medication",
        "what medicine", "which medicine", "should i stop taking", "treatment plan",
        "prescribe me", "am i bipolar", "am i depressed", "am i schizophrenic"
    ]
}
