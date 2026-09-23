import Foundation
import NaturalLanguage

/// A durable, user-authored correction. This is personalization data, not a
/// mutation of Apple's model weights.
struct FoodCorrectionMemory: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var normalizedText: String
    var displayText: String
    var verdict: FoodVerdict
    var correctedAt: Date
    var confirmationCount: Int
}

enum FoodMemoryStore {
    static let manualAssessment = "Marked manually and remembered."
    static let rememberedAssessment = "Learned from your correction."

    static func normalized(_ text: String) -> String {
        text
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func upserting(
        food: String,
        verdict: FoodVerdict,
        at date: Date = .now,
        in memories: [FoodCorrectionMemory]
    ) -> [FoodCorrectionMemory] {
        let key = normalized(food)
        guard !key.isEmpty, verdict != .unanalyzed else { return memories }

        var result = memories
        if let index = result.firstIndex(where: { $0.normalizedText == key }) {
            result[index].displayText = food.trimmingCharacters(in: .whitespacesAndNewlines)
            result[index].verdict = verdict
            result[index].correctedAt = date
            result[index].confirmationCount += 1
        } else {
            result.append(FoodCorrectionMemory(
                normalizedText: key,
                displayText: food.trimmingCharacters(in: .whitespacesAndNewlines),
                verdict: verdict,
                correctedAt: date,
                confirmationCount: 1
            ))
        }
        return result
    }

    static func merging(
        existing: [FoodCorrectionMemory],
        imported: [FoodCorrectionMemory]
    ) -> [FoodCorrectionMemory] {
        var byKey: [String: FoodCorrectionMemory] = [:]
        for memory in existing where memory.verdict != .unanalyzed && !memory.normalizedText.isEmpty {
            if let current = byKey[memory.normalizedText], current.correctedAt > memory.correctedAt {
                continue
            }
            byKey[memory.normalizedText] = memory
        }
        for candidate in imported where candidate.verdict != .unanalyzed && !candidate.normalizedText.isEmpty {
            guard let current = byKey[candidate.normalizedText] else {
                byKey[candidate.normalizedText] = candidate
                continue
            }
            if candidate.correctedAt > current.correctedAt {
                byKey[candidate.normalizedText] = candidate
            } else if candidate.correctedAt == current.correctedAt {
                var resolved = current
                resolved.confirmationCount = max(current.confirmationCount, candidate.confirmationCount)
                byKey[candidate.normalizedText] = resolved
            }
        }
        return Array(byKey.values)
    }

    /// Builds memories from backups made before correction memory existed.
    /// Those backups already contain the manually edited food rows.
    static func inferred(from logs: [BackupManager.DailyLogExport]) -> [FoodCorrectionMemory] {
        var entries: [FoodEntry] = []
        for log in logs {
            entries.append(contentsOf: log.foodEntries ?? [])
        }
        return inferred(from: entries)
    }

    static func inferred(from entries: [FoodEntry]) -> [FoodCorrectionMemory] {
        var correctedEntries = entries.filter { entry in
            entry.wasManuallyCorrected == true
                || entry.assessment == "Marked manually."
                || entry.assessment == manualAssessment
        }
        correctedEntries.sort { $0.timestamp < $1.timestamp }

        return correctedEntries.reduce(into: []) { memories, entry in
            memories = upserting(
                food: entry.text,
                verdict: entry.verdict,
                at: entry.timestamp,
                in: memories
            )
        }
    }
}

enum FoodMemoryMatcher {
    /// Exact normalized matches are deterministic and work even when Apple
    /// Intelligence is unavailable.
    static func exactMatch(
        for food: String,
        in memories: [FoodCorrectionMemory]
    ) -> FoodCorrectionMemory? {
        let key = FoodMemoryStore.normalized(food)
        return memories
            .filter { $0.normalizedText == key && $0.verdict != .unanalyzed }
            .max { $0.correctedAt < $1.correctedAt }
    }

    /// Nearby corrections are examples for the model, never hard overrides.
    /// A conservative cosine-distance ceiling reduces accidental matches;
    /// modifiers such as "fried" versus "grilled" remain for the model to
    /// evaluate in the full text.
    static func relatedMatches(
        for food: String,
        in memories: [FoodCorrectionMemory],
        maximumCount: Int = 3,
        maximumDistance: Double = 0.22
    ) -> [FoodCorrectionMemory] {
        guard maximumCount > 0,
              let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        else { return [] }

        let key = FoodMemoryStore.normalized(food)
        return memories
            .filter { $0.normalizedText != key && $0.verdict != .unanalyzed }
            .compactMap { memory -> (FoodCorrectionMemory, Double)? in
                let distance = embedding.distance(
                    between: key,
                    and: memory.normalizedText,
                    distanceType: .cosine
                )
                return distance <= maximumDistance ? (memory, distance) : nil
            }
            .sorted {
                if $0.1 == $1.1 { return $0.0.correctedAt > $1.0.correctedAt }
                return $0.1 < $1.1
            }
            .prefix(maximumCount)
            .map(\.0)
    }
}
