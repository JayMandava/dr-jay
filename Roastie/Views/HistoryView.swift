import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]

    private var streakStats: StreakStats { StreakCalculator.calculate(logs: logs) }

    var body: some View {
        List {
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
                    if foodEntries.isEmpty {
                        daySummary(log)
                    } else {
                        DisclosureGroup {
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
                                        DayCoordinator.shared.deleteFoodEntry(
                                            entryID: entry.id,
                                            dayKey: log.dayKey
                                        )
                                    }
                                )
                                .padding(.vertical, 4)
                            }
                        } label: {
                            daySummary(log, foodCount: foodEntries.count)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
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

    private func daySummary(_ log: DailyLog, foodCount: Int = 0) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Text("\(GoalCalculator.sleepDetail(hours: log.sleepHours)) · \(GoalCalculator.waterDetail(bottlesLogged: log.waterBottlesLogged, goal: log.waterGoalBottles))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if foodCount > 0 {
                    Text("\(foodCount) food entr\(foodCount == 1 ? "y" : "ies")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statusIcon(log)
        }
    }

    private func updateFood(_ entry: FoodEntry, in log: DailyLog, verdict: FoodVerdict) {
        DayCoordinator.shared.updateFoodVerdict(
            entryID: entry.id,
            dayKey: log.dayKey,
            verdict: verdict
        )
    }

    private func statusIcon(_ log: DailyLog) -> some View {
        let bothMet = log.sleepGoalMet == true && log.waterProgress >= 1
        return Image(systemName: bothMet ? "checkmark.circle.fill" : "flame.fill")
            .foregroundStyle(bothMet ? .green : .orange)
    }
}
