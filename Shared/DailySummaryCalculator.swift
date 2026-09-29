import Foundation

struct DailySummaryInput: Equatable, Sendable {
    let sleepHours: Double?
    let waterBottlesLogged: Int
    let waterGoalBottles: Int
    let foodScore: Int?
    let steps: Int?
}

struct DailySummaryResult: Equatable, Sendable {
    let score: Int
    let band: DailySummaryBand
    let isComplete: Bool
    let detail: String
    let roast: String
}

enum DailySummaryBand: String, Equatable, Sendable {
    case good = "Good"
    case bad = "Bad"
    case ugly = "Ugly"

    static func classify(_ score: Int) -> Self {
        switch score {
        case 80...: .good
        case 60..<80: .bad
        default: .ugly
        }
    }
}

enum DailySummaryCalculator {
    // Steps intentionally contribute only 5%. Eight thousand is a soft
    // normalization ceiling, not a stored goal or medical recommendation.
    private static let stepReference = 8_000.0

    static func calculate(
        _ input: DailySummaryInput,
        intensity: RoastIntensity = .playful
    ) -> DailySummaryResult {
        var weightedScores: [(score: Double, weight: Double)] = []

        if let hours = input.sleepHours {
            weightedScores.append((sleepScore(hours), 0.30))
        }

        let waterGoal = max(1, input.waterGoalBottles)
        let waterScore = min(1, Double(max(0, input.waterBottlesLogged)) / Double(waterGoal)) * 100
        weightedScores.append((waterScore, 0.30))

        if let foodScore = input.foodScore {
            weightedScores.append((Double(foodScore.clamped(to: 0...100)), 0.35))
        }

        if let steps = input.steps {
            let stepScore = min(1, Double(max(0, steps)) / stepReference) * 100
            weightedScores.append((stepScore, 0.05))
        }

        let totalWeight = weightedScores.reduce(0) { $0 + $1.weight }
        let score = Int((weightedScores.reduce(0) { $0 + $1.score * $1.weight } / totalWeight).rounded())
        let band = DailySummaryBand.classify(score)
        let complete = input.sleepHours != nil && input.foodScore != nil

        return DailySummaryResult(
            score: score,
            band: band,
            isComplete: complete,
            detail: detail(for: input),
            roast: roast(for: band, complete: complete, intensity: intensity)
        )
    }

    private static func sleepScore(_ hours: Double) -> Double {
        if hours < AppConfig.sleepGoalHours {
            return max(0, hours / AppConfig.sleepGoalHours * 100)
        }
        if hours <= AppConfig.sleepGoalMaxHours {
            return 100
        }
        return max(0, 100 - (hours - AppConfig.sleepGoalMaxHours) * 20)
    }

    private static func detail(for input: DailySummaryInput) -> String {
        let sleep = input.sleepHours.map { String(format: "Sleep %.1fh", $0) } ?? "Sleep —"
        let water = "Water \(max(0, input.waterBottlesLogged))/\(max(1, input.waterGoalBottles))"
        let food = input.foodScore.map { "Food \($0.clamped(to: 0...100))" } ?? "Food —"
        let steps = input.steps.map { "Steps \($0.formatted())" } ?? "Steps —"
        return [sleep, water, food, steps].joined(separator: " · ")
    }

    private static func roast(
        for band: DailySummaryBand,
        complete: Bool,
        intensity: RoastIntensity
    ) -> String {
        guard complete else {
            return switch intensity {
            case .gentle: "Incomplete chart. Even the paperwork would like a little more effort."
            case .playful: "Incomplete chart. Apparently documentation is optional now."
            case .spicy: "Incomplete chart. Even your excuses arrived with missing data."
            }
        }
        switch (band, intensity) {
        case (.good, .gentle):
            return "Good day. Quiet competence looks surprisingly natural on you."
        case (.good, .playful):
            return "Good day. Try not to make competence a one-off event."
        case (.good, .spicy):
            return "Good day. Basic self-maintenance finally cleared the unusually low bar."
        case (.bad, .gentle):
            return "Bad, but recoverable. The chart is disappointed, not surprised."
        case (.bad, .playful):
            return "Bad, but recoverable. The chart has seen worse—mostly from you."
        case (.bad, .spicy):
            return "Bad. You built a preventable mess and called it a routine day."
        case (.ugly, .gentle):
            return "Ugly. The chart has stopped trying to be subtle."
        case (.ugly, .playful):
            return "Ugly. Even your excuses need better nutrition."
        case (.ugly, .spicy):
            return "Ugly. The evidence is overwhelming and your choices have no defense."
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
