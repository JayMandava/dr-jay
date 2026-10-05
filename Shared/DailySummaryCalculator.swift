import Foundation

struct DailySummaryInput: Equatable, Sendable {
    let sleepHours: Double?
    let waterBottlesLogged: Int
    let waterGoalBottles: Int
    let foodScore: Int?
    let steps: Int?
    let exerciseMinutes: Int?
    let exerciseEntryCount: Int
}

struct DailySummaryResult: Equatable, Sendable {
    let score: Int
    let band: DailySummaryBand
    let isComplete: Bool
    let detail: String
    let roast: String
    let profile: DailyScoreProfile
    let weightBreakdown: [DailyScoreWeightBreakdown]
}

enum DailyScoreMetric: String, CaseIterable, Hashable, Sendable {
    case food
    case sleep
    case water
    case movement

    var label: String { rawValue.capitalized }
}

struct DailyScoreWeightBreakdown: Equatable, Sendable {
    let metric: DailyScoreMetric
    let configuredWeight: Double
    let effectiveWeight: Double?
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
    // Movement's contribution follows the selected profile. Eight thousand is a soft
    // normalization ceiling, not a stored goal or medical recommendation.
    private static let stepReference = 8_000.0

    static func calculate(
        _ input: DailySummaryInput,
        intensity: RoastIntensity = .gentle,
        profile: DailyScoreProfile = .balanced,
        foodRoastsEnabled: Bool = true
    ) -> DailySummaryResult {
        let weights = profile.weights
        var weightedScores: [(metric: DailyScoreMetric, score: Double, weight: Double)] = []

        if let hours = input.sleepHours {
            weightedScores.append((.sleep, sleepScore(hours), weights.sleep))
        }

        let waterGoal = max(1, input.waterGoalBottles)
        let waterScore = min(1, Double(max(0, input.waterBottlesLogged)) / Double(waterGoal)) * 100
        weightedScores.append((.water, waterScore, weights.water))

        if let foodScore = input.foodScore {
            weightedScores.append((.food, Double(foodScore.clamped(to: 0...100)), weights.food))
        }

        let stepScore = input.steps.map {
            min(1, Double(max(0, $0)) / stepReference) * 100
        }
        let exerciseScore = ExerciseAnalyzer.score(minutes: input.exerciseMinutes)
        if let movementScore = [stepScore, exerciseScore].compactMap({ $0 }).max() {
            weightedScores.append((.movement, movementScore, weights.movement))
        }

        let totalWeight = weightedScores.reduce(0) { $0 + $1.weight }
        let score = Int((weightedScores.reduce(0) { $0 + $1.score * $1.weight } / totalWeight).rounded())
        let band = DailySummaryBand.classify(score)
        let complete = input.sleepHours != nil && input.foodScore != nil
        let configuredWeights: [DailyScoreMetric: Double] = [
            .food: weights.food,
            .sleep: weights.sleep,
            .water: weights.water,
            .movement: weights.movement,
        ]
        let availableMetrics = Set(weightedScores.map(\.metric))
        let breakdown = DailyScoreMetric.allCases.map { metric in
            DailyScoreWeightBreakdown(
                metric: metric,
                configuredWeight: configuredWeights[metric] ?? 0,
                effectiveWeight: availableMetrics.contains(metric)
                    ? (configuredWeights[metric] ?? 0) / totalWeight
                    : nil
            )
        }

        return DailySummaryResult(
            score: score,
            band: band,
            isComplete: complete,
            detail: detail(for: input),
            roast: roast(
                for: input,
                band: band,
                complete: complete,
                intensity: intensity,
                foodRoastsEnabled: foodRoastsEnabled
            ),
            profile: profile,
            weightBreakdown: breakdown
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
        let exercise: String?
        if let minutes = input.exerciseMinutes {
            exercise = "Exercise \(minutes)m"
        } else if input.exerciseEntryCount > 0 {
            exercise = "Exercise logged"
        } else {
            exercise = nil
        }
        return [sleep, water, food, steps, exercise].compactMap { $0 }.joined(separator: " · ")
    }

    private static func roast(
        for input: DailySummaryInput,
        band: DailySummaryBand,
        complete: Bool,
        intensity: RoastIntensity,
        foodRoastsEnabled: Bool
    ) -> String {
        let target = roastTarget(
            for: input,
            band: band,
            complete: complete,
            foodRoastsEnabled: foodRoastsEnabled
        )
        return "\(band.rawValue). \(RoastStyleContract.fallback(target: target, intensity: intensity))"
    }

    private static func roastTarget(
        for input: DailySummaryInput,
        band: DailySummaryBand,
        complete: Bool,
        foodRoastsEnabled: Bool
    ) -> RoastTarget {
        guard complete else { return .missingData }
        if foodRoastsEnabled {
            if let food = input.foodScore, food < 60 { return .foodUgly }
            if let food = input.foodScore, food < 80 { return .foodBad }
        }
        if let sleep = input.sleepHours, sleep < AppConfig.sleepGoalHours { return .sleepUnder }
        if let sleep = input.sleepHours, sleep > AppConfig.sleepGoalMaxHours { return .sleepOver }
        if input.waterBottlesLogged < max(1, input.waterGoalBottles) { return .waterIncomplete }
        return switch band {
        case .good: .allGood
        case .bad: .overallBad
        case .ugly: .overallUgly
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
