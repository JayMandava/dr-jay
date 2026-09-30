import Foundation

struct ExerciseSummary: Equatable, Sendable {
    let entryCount: Int
    let scoredEntryCount: Int
    let totalMinutes: Int

    var scoredMinutes: Int? { scoredEntryCount > 0 ? totalMinutes : nil }
}

/// Keeps exercise interpretation deterministic: the original text is always
/// saved, and only a duration explicitly present in that text can affect a score.
enum ExerciseAnalyzer {
    static func entry(from rawText: String, at timestamp: Date = .now) -> ExerciseEntry? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return ExerciseEntry(
            text: text,
            timestamp: timestamp,
            category: category(for: text),
            durationMinutes: explicitDurationMinutes(in: text)
        )
    }

    static func summary(entries: [ExerciseEntry]) -> ExerciseSummary {
        let durations = entries.compactMap(\.durationMinutes)
        return ExerciseSummary(
            entryCount: entries.count,
            scoredEntryCount: durations.count,
            totalMinutes: durations.reduce(0, +)
        )
    }

    static func score(minutes: Int?) -> Double? {
        guard let minutes, minutes > 0 else { return nil }
        return min(100, Double(minutes) / 30 * 100)
    }

    private static func explicitDurationMinutes(in text: String) -> Int? {
        let lower = text.lowercased()
        var total = 0.0
        var matched = false

        for pattern in [
            #"\b(\d+(?:\.\d+)?)\s*-?\s*(?:hours?|hrs?|hr|h)\b"#,
            #"\b(\d+(?:\.\d+)?)\s*-?\s*(?:minutes?|mins?|min|m)\b"#,
        ] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(lower.startIndex..<lower.endIndex, in: lower)
            for result in regex.matches(in: lower, range: range) {
                guard result.numberOfRanges > 1,
                      let valueRange = Range(result.range(at: 1), in: lower),
                      let value = Double(lower[valueRange])
                else { continue }
                matched = true
                total += pattern.contains("hours") ? value * 60 : value
            }
        }

        if !matched, lower.range(of: #"\b(?:half an hour|half hour)\b"#, options: .regularExpression) != nil {
            total = 30
            matched = true
        }

        guard matched else { return nil }
        return min(1_440, max(1, Int(total.rounded())))
    }

    private static func category(for text: String) -> ExerciseCategory {
        let words = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
        if !words.isDisjoint(with: ["yoga", "stretch", "stretching", "mobility", "pilates"]) {
            return .mobility
        }
        if !words.isDisjoint(with: ["gym", "weight", "weights", "lifting", "strength", "pushup", "pushups", "squat", "squats", "deadlift", "bench", "resistance"]) {
            return .strength
        }
        if !words.isDisjoint(with: ["badminton", "cricket", "football", "soccer", "basketball", "tennis", "pickleball", "sport", "volleyball", "hockey"]) {
            return .sport
        }
        if !words.isDisjoint(with: ["run", "running", "jog", "jogging", "walk", "walking", "cycle", "cycling", "bike", "biking", "swim", "swimming", "cardio", "treadmill", "rowing", "skipping", "hike", "hiking"]) {
            return .cardio
        }
        return .other
    }
}
