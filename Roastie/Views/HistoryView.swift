import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @State private var settings = SharedStore.loadSettings()

    private var streakStats: StreakStats { StreakCalculator.calculate(logs: logs) }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    InsightsView(
                        intensity: settings.roastIntensity,
                        foodRoastsEnabled: settings.foodRoastsEnabled
                    )
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dr Jay Insights")
                                .font(.headline)
                            Text("7 and 30-day patterns, priorities, and direction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundStyle(DrJayTheme.primary)
                    }
                }
            }

            Section("Consistency") {
                HStack(spacing: 0) {
                    metric(value: streakStats.current, label: "Current")
                    Divider()
                    metric(value: streakStats.longest, label: "Longest")
                    Divider()
                    metric(value: streakStats.perfectDays, label: "Perfect days")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Daily history") {
                ForEach(logs) { log in
                    let foodEntries = (log.foodEntries ?? []).sorted { $0.timestamp < $1.timestamp }
                    let exerciseEntries = (log.exerciseEntries ?? []).sorted { $0.timestamp < $1.timestamp }
                    if foodEntries.isEmpty && exerciseEntries.isEmpty {
                        daySummary(log)
                    } else {
                        DisclosureGroup {
                            if !foodEntries.isEmpty {
                                Text("Food")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(foodEntries) { entry in
                                FoodEntryRow(
                                    entry: entry,
                                    onMarkHealthy: {
                                        updateFood(entry, in: log, verdict: .healthy)
                                    },
                                    onMarkUnhealthy: {
                                        updateFood(entry, in: log, verdict: .unhealthy)
                                    },
                                    onDelete: {
                                        Task {
                                            await DayCoordinator.shared.deleteFoodEntry(
                                                entryID: entry.id,
                                                dayKey: log.dayKey
                                            )
                                        }
                                    }
                                )
                                .padding(.vertical, 4)
                            }

                            if !exerciseEntries.isEmpty {
                                Text("Exercise")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(exerciseEntries) { entry in
                                ExerciseEntryRow(entry: entry) {
                                    Task {
                                        await DayCoordinator.shared.deleteExerciseEntry(
                                            entryID: entry.id,
                                            dayKey: log.dayKey
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } label: {
                            daySummary(
                                log,
                                foodCount: foodEntries.count,
                                exerciseCount: exerciseEntries.count
                            )
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DrJayTheme.canvas)
        .navigationTitle("History")
        .tint(DrJayTheme.primary)
    }

    private func metric(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func daySummary(
        _ log: DailyLog,
        foodCount: Int = 0,
        exerciseCount: Int = 0
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Text("\(GoalCalculator.sleepDetail(hours: log.sleepHours)) · \(GoalCalculator.waterDetail(bottlesLogged: log.waterBottlesLogged, goal: log.waterGoalBottles))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if foodCount > 0 {
                    Text(foodSummary(log, count: foodCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if exerciseCount > 0 {
                    Text(exerciseSummary(log, count: exerciseCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statusIcon(log)
        }
    }

    private func updateFood(_ entry: FoodEntry, in log: DailyLog, verdict: FoodVerdict) {
        Task {
            await DayCoordinator.shared.updateFoodVerdict(
                entryID: entry.id,
                dayKey: log.dayKey,
                verdict: verdict
            )
        }
    }

    private func foodSummary(_ log: DailyLog, count: Int) -> String {
        let entryCount = "\(count) food entr\(count == 1 ? "y" : "ies")"
        guard let score = log.foodScore else { return "\(entryCount) · Food score —" }
        return "\(entryCount) · \(score) \(FoodScoreBand.classify(score).rawValue)"
    }

    private func exerciseSummary(_ log: DailyLog, count: Int) -> String {
        let summary = ExerciseAnalyzer.summary(entries: log.exerciseEntries ?? [])
        let sessions = "\(count) exercise session\(count == 1 ? "" : "s")"
        guard let minutes = summary.scoredMinutes else { return "\(sessions) · Duration —" }
        return "\(sessions) · \(minutes) min"
    }

    private func statusIcon(_ log: DailyLog) -> some View {
        let bothMet = log.sleepGoalMet == true && log.waterProgress >= 1
        return Image(systemName: bothMet ? "checkmark.circle.fill" : "flame.fill")
            .foregroundStyle(bothMet ? DrJayTheme.primary : DrJayTheme.roast)
    }
}
