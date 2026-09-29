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
            roast: roast(for: input, band: band, complete: complete, intensity: intensity)
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
        for input: DailySummaryInput,
        band: DailySummaryBand,
        complete: Bool,
        intensity: RoastIntensity
    ) -> String {
        let target = roastTarget(for: input, complete: complete)
        return "\(band.rawValue). \(RoastStyleContract.fallback(target: target, intensity: intensity))"
    }

    private static func roastTarget(
        for input: DailySummaryInput,
        complete: Bool
    ) -> RoastTarget {
        guard complete else { return .missingData }
        if let food = input.foodScore, food < 60 { return .foodUgly }
        if let food = input.foodScore, food < 80 { return .foodBad }
        if let sleep = input.sleepHours, sleep < AppConfig.sleepGoalHours { return .sleepUnder }
        if let sleep = input.sleepHours, sleep > AppConfig.sleepGoalMaxHours { return .sleepOver }
        if input.waterBottlesLogged < max(1, input.waterGoalBottles) { return .waterIncomplete }
        return .allGood
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
