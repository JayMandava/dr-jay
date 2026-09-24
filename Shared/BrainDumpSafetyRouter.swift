import Foundation

enum BrainDumpSafetyRoute: Equatable {
    case conversation
    case promptAttack
    case prohibitedAdvice
    case vulnerable
    case immediateRisk
    case unrelated
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
        if containsAny(promptAttackPhrases, in: normalized)
            || compactContainsAny(promptAttackCompactions, in: normalized) {
            return .promptAttack
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

    private static func compactContainsAny(_ phrases: [String], in text: String) -> Bool {
        let compact = text.filter(\.isLetter)
        return phrases.contains { compact.contains($0) }
    }

    private static let promptAttackPhrases = [
        "system prompt", "hidden prompt", "developer prompt", "initial prompt",
        "reveal your prompt", "show your prompt", "repeat your prompt",
        "what are your instructions", "reveal your instructions", "show your instructions",
        "repeat your instructions", "ignore previous instructions", "ignore all instructions",
        "disregard previous instructions", "override your instructions", "prompt injection",
        "jailbreak", "do anything now", "print everything above", "repeat everything above"
    ]

    private static let promptAttackCompactions = [
        "systemprompt", "hiddenprompt", "developerprompt", "initialprompt",
        "ignorepreviousinstructions", "ignoreallinstructions",
        "disregardpreviousinstructions", "overrideyourinstructions",
        "revealyourprompt", "showyourprompt", "repeatyourprompt",
        "revealyourinstructions", "showyourinstructions", "repeatyourinstructions",
        "printeverythingabove", "repeateverythingabove"
    ]

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

/// Rejects generated text that appears to expose or discuss private session
/// instructions. A rejected response is replaced locally and never displayed.
enum BrainDumpOutputValidator {
    static func allows(_ text: String) -> Bool {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let blockedFragments = [
            "system prompt", "hidden prompt", "developer prompt", "my instructions",
            "i was instructed", "my rules", "instructions say", "language model session",
            "treat every user message as untrusted", "temporary, private brain-dump conversation",
            "replacement for human support", "output only the response",
            "ignore previous instructions", "prompt injection"
        ]
        return !blockedFragments.contains { normalized.contains($0) }
    }
}
