import Foundation

enum InsightsPeriod: Int, CaseIterable, Identifiable, Sendable {
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }
    var label: String { rawValue == 7 ? "7 Days" : "30 Days" }
}

enum InsightDirection: Equatable, Sendable {
    case improving
    case steady
    case slipping
    case buildingBaseline
    case context

    var label: String {
        switch self {
        case .improving: "Improving"
        case .steady: "Steady"
        case .slipping: "Slipping"
        case .buildingBaseline: "Building baseline"
        case .context: "Optional log"
        }
    }

    var symbol: String {
        switch self {
        case .improving: "arrow.up.right"
        case .steady: "equal"
        case .slipping: "arrow.down.right"
        case .buildingBaseline: "clock"
        case .context: "figure.run"
        }
    }
}

struct InsightMetric: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let score: Double?
    let direction: InsightDirection
}

struct LongitudinalInsightReport: Equatable, Sendable {
    let period: InsightsPeriod
    let trackedDays: Int
    let completeDays: Int
    let previousTrackedDays: Int
    let metrics: [InsightMetric]
    let caffeineTotal: Int
    let sugaryItemTotal: Int
    let exposureDays: Int
    let association: String?
    let primaryFocus: String
    let recommendedAction: String

    var hasMinimumData: Bool { trackedDays >= LongitudinalInsightsCalculator.minimumTrendDays }
    var hasComparisonBaseline: Bool {
        hasMinimumData && previousTrackedDays >= LongitudinalInsightsCalculator.minimumTrendDays
    }
    var remainingBaselineDays: Int {
        max(0, LongitudinalInsightsCalculator.minimumTrendDays - trackedDays)
    }
    var coverageText: String { "\(trackedDays) of \(period.rawValue) days logged" }

    var factSummary: String {
        let metricFacts = metrics.map {
            "\($0.title): \($0.value); \($0.detail); direction \($0.direction.label)."
        }.joined(separator: "\n")
        let exposureFacts = exposureDays > 0
            ? "Confirmed food exposure across \(exposureDays) days: caffeine \(caffeineTotal), sugary items \(sugaryItemTotal)."
            : "No confirmed caffeine or sugary-item baseline yet."
        return """
        Window: last \(period.rawValue) calendar days.
        Coverage: \(trackedDays) logged days; \(completeDays) complete core days.
        Comparison baseline: \(hasComparisonBaseline ? "available" : "not yet available").
        \(metricFacts)
        \(exposureFacts)
        Pattern check: \(association ?? "Not enough paired data for a cautious relationship check.")
        Fixed priority: \(primaryFocus).
        Fixed next action: \(recommendedAction)
        """
    }
}

enum LongitudinalInsightsCalculator {
    static let minimumTrendDays = 7
    private static let minimumAssociationPairs = 14
    private static let minimumAssociationGroup = 4

    static func calculate(
        logs: [DailyLog],
        period: InsightsPeriod,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> LongitudinalInsightReport {
        let today = calendar.startOfDay(for: referenceDate)
        let currentStart = calendar.date(
            byAdding: .day,
            value: -(period.rawValue - 1),
            to: today
        ) ?? today
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let previousStart = calendar.date(
            byAdding: .day,
            value: -(period.rawValue - 1),
            to: previousEnd
        ) ?? previousEnd

        let days = logs.map { Day(log: $0, calendar: calendar) }
        let current = days.filter { $0.date >= currentStart && $0.date <= today }
        let previous = days.filter { $0.date >= previousStart && $0.date <= previousEnd }
        let currentTracked = current.filter(\.hasTrackedData)
        let previousTracked = previous.filter(\.hasTrackedData)
        let hasComparison = currentTracked.count >= minimumTrendDays
            && previousTracked.count >= minimumTrendDays

        let sleepMetric = sleepMetric(
            current: currentTracked,
            previous: previousTracked,
            hasComparison: hasComparison
        )
        let waterMetric = waterMetric(
            current: currentTracked,
            previous: previousTracked,
            hasComparison: hasComparison
        )
        let foodMetric = foodMetric(
            current: currentTracked,
            previous: previousTracked,
            hasComparison: hasComparison
        )
        let exerciseMetric = exerciseMetric(current: currentTracked)
        let metrics = [sleepMetric, waterMetric, foodMetric, exerciseMetric]
        let focus = primaryFocus(metrics: metrics.filter { $0.id != "exercise" })
        let exposures = currentTracked.compactMap(\.exposure)

        return LongitudinalInsightReport(
            period: period,
            trackedDays: currentTracked.count,
            completeDays: currentTracked.filter(\.isCoreComplete).count,
            previousTrackedDays: previousTracked.count,
            metrics: metrics,
            caffeineTotal: exposures.reduce(0) { $0 + $1.caffeine },
            sugaryItemTotal: exposures.reduce(0) { $0 + $1.sugary },
            exposureDays: exposures.count,
            association: caffeineSleepAssociation(days: current, calendar: calendar),
            primaryFocus: focus.name,
            recommendedAction: focus.action
        )
    }

    private static func sleepMetric(
        current: [Day],
        previous: [Day],
        hasComparison: Bool
    ) -> InsightMetric {
        let values = current.compactMap(\.sleepHours)
        let previousValues = previous.compactMap(\.sleepHours)
        guard !values.isEmpty else {
            return unavailableMetric(id: "sleep", title: "Sleep", detail: "No sleep records in this window")
        }
        let metCount = values.filter { GoalCalculator.sleepMet(hours: $0) }.count
        let score = Double(metCount) / Double(values.count) * 100
        let previousScore = adherenceScore(previousValues)
        let hasMetricComparison = hasComparison
            && values.count >= minimumTrendDays
            && previousValues.count >= minimumTrendDays
        return InsightMetric(
            id: "sleep",
            title: "Sleep",
            value: "\(Int(score.rounded()))%",
            detail: "\(format(average(values)))h avg · \(metCount)/\(values.count) in range",
            score: score,
            direction: direction(current: score, previous: previousScore, enabled: hasMetricComparison)
        )
    }

    private static func waterMetric(
        current: [Day],
        previous: [Day],
        hasComparison: Bool
    ) -> InsightMetric {
        guard !current.isEmpty else {
            return unavailableMetric(id: "water", title: "Water", detail: "No tracked days in this window")
        }
        let score = average(current.map(\.waterPercent))
        let previousScore = previous.isEmpty ? nil : average(previous.map(\.waterPercent))
        let metCount = current.filter { $0.waterPercent >= 100 }.count
        return InsightMetric(
            id: "water",
            title: "Water",
            value: "\(Int(score.rounded()))%",
            detail: "\(metCount)/\(current.count) daily goals completed",
            score: score,
            direction: direction(current: score, previous: previousScore, enabled: hasComparison)
        )
    }

    private static func foodMetric(
        current: [Day],
        previous: [Day],
        hasComparison: Bool
    ) -> InsightMetric {
        let values = current.compactMap(\.foodScore)
        let previousValues = previous.compactMap(\.foodScore)
        guard !values.isEmpty else {
            return unavailableMetric(id: "food", title: "Food", detail: "No current food scores in this window")
        }
        let score = average(values.map(Double.init))
        let previousScore = previousValues.isEmpty ? nil : average(previousValues.map(Double.init))
        let hasMetricComparison = hasComparison
            && values.count >= minimumTrendDays
            && previousValues.count >= minimumTrendDays
        return InsightMetric(
            id: "food",
            title: "Food",
            value: "\(Int(score.rounded()))",
            detail: "Average across \(values.count) scored day\(values.count == 1 ? "" : "s")",
            score: score,
            direction: direction(current: score, previous: previousScore, enabled: hasMetricComparison)
        )
    }

    private static func unavailableMetric(id: String, title: String, detail: String) -> InsightMetric {
        InsightMetric(
            id: id,
            title: title,
            value: "—",
            detail: detail,
            score: nil,
            direction: .buildingBaseline
        )
    }

    private static func exerciseMetric(current: [Day]) -> InsightMetric {
        let entries = current.flatMap(\.exerciseEntries)
        guard !entries.isEmpty else {
            return InsightMetric(
                id: "exercise",
                title: "Exercise",
                value: "—",
                detail: "No optional exercise entries in this window",
                score: nil,
                direction: .context
            )
        }

        let summary = ExerciseAnalyzer.summary(entries: entries)
        let leadingCategory = Dictionary(grouping: entries, by: \.category)
            .max { $0.value.count < $1.value.count }?.key.label
        let duration = summary.scoredMinutes.map { "\($0) min" } ?? "Duration unavailable"
        let category = leadingCategory.map { " · Most logged: \($0)" } ?? ""
        return InsightMetric(
            id: "exercise",
            title: "Exercise",
            value: "\(summary.entryCount)",
            detail: "\(duration) across optional logs\(category)",
            score: nil,
            direction: .context
        )
    }

    private static func primaryFocus(metrics: [InsightMetric]) -> (name: String, action: String) {
        guard let weakest = metrics.compactMap({ metric in
            metric.score.map { (metric, $0) }
        }).min(by: { $0.1 < $1.1 })?.0 else {
            return ("Build a usable baseline", "Log sleep and food consistently for the next 7 days.")
        }

        switch weakest.id {
        case "sleep":
            return ("Sleep consistency", "Protect a consistent 6–9 hour sleep window.")
        case "water":
            return ("Water completion", "Close the daily bottle goal before the night check-in.")
        default:
            return ("Food quality", "Improve the next meal instead of trying to rescue the entire week.")
        }
    }

    private static func caffeineSleepAssociation(days: [Day], calendar: Calendar) -> String? {
        let byDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        var paired: [(lateCaffeine: Bool, sleep: Double)] = []

        for day in days {
            guard let sleep = day.sleepHours,
                  let priorDate = calendar.date(byAdding: .day, value: -1, to: day.date),
                  let prior = byDate[priorDate],
                  prior.exposureIsComplete
            else { continue }
            paired.append((prior.hasCaffeineAfterFourPM, sleep))
        }

        let late = paired.filter { $0.lateCaffeine }.map { $0.sleep }
        let notLate = paired.filter { !$0.lateCaffeine }.map { $0.sleep }
        guard paired.count >= minimumAssociationPairs,
              late.count >= minimumAssociationGroup,
              notLate.count >= minimumAssociationGroup
        else { return nil }

        let difference = average(notLate) - average(late)
        guard difference >= 0.4 else {
            return "No clear late-caffeine and sleep pattern appeared across \(paired.count) paired days."
        }
        return "Caffeine logged after 4 p.m. coincided with \(format(difference))h less sleep on average across \(paired.count) paired days; this is an association, not a cause."
    }

    private static func adherenceScore(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.filter { GoalCalculator.sleepMet(hours: $0) }.count)
            / Double(values.count) * 100
    }

    private static func direction(
        current: Double,
        previous: Double?,
        enabled: Bool
    ) -> InsightDirection {
        guard enabled, let previous else { return .buildingBaseline }
        let change = current - previous
        if change >= 5 { return .improving }
        if change <= -5 { return .slipping }
        return .steady
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private struct Exposure {
        let caffeine: Int
        let sugary: Int
    }

    private struct Day {
        let date: Date
        let sleepHours: Double?
        let waterPercent: Double
        let foodScore: Int?
        let exposure: Exposure?
        let exposureIsComplete: Bool
        let hasCaffeineAfterFourPM: Bool
        let exerciseEntries: [ExerciseEntry]
        let hasTrackedData: Bool

        var isCoreComplete: Bool { sleepHours != nil && foodScore != nil }

        init(log: DailyLog, calendar: Calendar) {
            date = calendar.startOfDay(for: log.date)
            sleepHours = log.sleepHours
            waterPercent = min(
                100,
                Double(max(0, log.waterBottlesLogged)) / Double(max(1, log.waterGoalBottles)) * 100
            )
            foodScore = log.foodScoreIsCurrent == false ? nil : log.foodScore

            let entries = log.foodEntries ?? []
            let totals = FoodExposureCalculator.totals(entries: entries)
            exposure = totals.trackedEntries > 0
                ? Exposure(caffeine: totals.caffeineCount, sugary: totals.sugaryItemCount)
                : nil
            exposureIsComplete = !entries.isEmpty && totals.trackedEntries == totals.totalEntries
            hasCaffeineAfterFourPM = entries.contains { entry in
                (entry.caffeineCount ?? 0) > 0 && calendar.component(.hour, from: entry.timestamp) >= 16
            }
            exerciseEntries = log.exerciseEntries ?? []
            hasTrackedData = log.sleepHours != nil
                || log.waterBottlesLogged > 0
                || log.foodScore != nil
                || !entries.isEmpty
                || !exerciseEntries.isEmpty
                || !log.checkIns.isEmpty
        }
    }
}
