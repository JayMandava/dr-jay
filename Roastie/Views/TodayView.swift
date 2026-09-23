import SwiftUI
import SwiftData

struct TodayView: View {
    @Binding var settings: AppSettings
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @State private var showSettings = false
    @State private var showSleepSheet = false
    @State private var showFoodSheet = false
    @State private var isLoggingWater = false
    @State private var loggedFoodResult: FoodEntry?
    @State private var foodFeedback: FoodFeedback?

    private var today: DailyLog? { logs.first { $0.dayKey == Date().dayKey } }
    private var streakStats: StreakStats { StreakCalculator.calculate(logs: logs) }
    private var foodEntries: [FoodEntry] {
        (today?.foodEntries ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        RingView(
                            progress: today?.sleepProgress ?? 0,
                            color: .indigo,
                            icon: "moon.zzz.fill",
                            title: "Sleep",
                            subtitle: sleepSubtitle
                        )
                        RingView(
                            progress: today?.waterProgress ?? 0,
                            color: .cyan,
                            icon: "drop.fill",
                            title: "Water",
                            subtitle: GoalCalculator.waterDetail(bottlesLogged: today?.waterBottlesLogged ?? 0, goal: today?.waterGoalBottles ?? settings.waterGoalBottles)
                        )
                    }
                    .padding(.top, 8)

                    if let latest = today?.checkIns.last {
                        LatestMessageCard(record: latest)
                            .id(latest.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    HStack(spacing: 12) {
                        Button {
                            Haptics.tap()
                            showSleepSheet = true
                        } label: {
                            Label("Log Sleep", systemImage: "moon.zzz.fill")
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .tint(.indigo)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .background(.indigo.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.indigo)

                        Button {
                            Haptics.tap()
                            isLoggingWater = true
                            Task {
                                await DayCoordinator.shared.logWaterBottle()
                                isLoggingWater = false
                            }
                        } label: {
                            Label(isLoggingWater ? "Logging…" : "Log Bottle", systemImage: "drop.fill")
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(isLoggingWater)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .background(.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.cyan)
                    }
                    .font(.subheadline.weight(.semibold))

                    Button {
                        Haptics.tap()
                        showFoodSheet = true
                    } label: {
                        Label("Log Food", systemImage: "fork.knife")
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .background(.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.semibold))

                    if !foodEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Food today", systemImage: "fork.knife")
                                .font(.headline)

                            FoodScoreSummary(
                                score: today?.foodScore,
                                summary: today?.foodScoreSummary,
                                isCurrent: today?.foodScoreIsCurrent == true
                            )

                            Divider()

                            ForEach(foodEntries) { entry in
                                FoodEntryRow(
                                    entry: entry,
                                    onMarkHealthy: {
                                        updateFood(entry, verdict: .healthy)
                                    },
                                    onMarkUnhealthy: {
                                        updateFood(entry, verdict: .unhealthy)
                                    },
                                    onDelete: {
                                        deleteFood(entry)
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }

                    HStack {
                        Label(currentStreakLabel, systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("Best \(streakStats.longest)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    if let today, !today.checkIns.isEmpty {
                        CheckInTimeline(checkIns: today.checkIns.sorted { $0.timestamp > $1.timestamp })
                    }
                }
                .padding()
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: today?.checkIns.last?.id)
            }
            .navigationTitle("Dr Jay")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: $settings)
            }
            .sheet(isPresented: $showSleepSheet) {
                LogSleepSheet(
                    currentTotal: today?.sleepHours,
                    healthKitEnabled: settings.healthKitEnabled,
                    onSave: { hours in
                        Task { await DayCoordinator.shared.logSleepHours(hours) }
                    },
                    onReplaceWithHealth: {
                        await DayCoordinator.shared.replaceSleepWithHealthData()
                    }
                )
            }
            .sheet(isPresented: $showFoodSheet, onDismiss: presentFoodFeedback) {
                LogFoodSheet(
                    onSave: { description in
                        await DayCoordinator.shared.logFood(description)
                    },
                    onLogged: { entry in
                        loggedFoodResult = entry
                    }
                )
            }
            .alert(item: $foodFeedback) { feedback in
                Alert(
                    title: Text(feedback.title),
                    message: Text(feedback.message),
                    dismissButton: .default(Text("Noted"))
                )
            }
            .task {
                await DayCoordinator.shared.refreshToday()
            }
        }
    }

    private var currentStreakLabel: String {
        streakStats.current > 0
            ? "\(streakStats.current)-day streak"
            : "Start a streak today"
    }

    private var sleepSubtitle: String {
        let detail = GoalCalculator.sleepDetail(hours: today?.sleepHours)
        switch today?.sleepSource {
        case "healthkit": return "\(detail) · Health"
        case "manual": return "\(detail) · Manual"
        default: return detail
        }
    }

    private func presentFoodFeedback() {
        guard let entry = loggedFoodResult else { return }
        loggedFoodResult = nil

        switch entry.verdict {
        case .unhealthy:
            foodFeedback = FoodFeedback(
                title: "Dr Jay’s diagnosis",
                message: entry.roast ?? "The chart says unhealthy. Even without commentary, the evidence is unflattering."
            )
        case .unanalyzed:
            foodFeedback = FoodFeedback(
                title: "Food logged",
                message: "Dr Jay couldn’t analyse this entry on this device. You can classify it from the food list."
            )
        case .healthy:
            break
        }
    }

    private func updateFood(_ entry: FoodEntry, verdict: FoodVerdict) {
        Task {
            await DayCoordinator.shared.updateFoodVerdict(
                entryID: entry.id,
                dayKey: today?.dayKey ?? Date().dayKey,
                verdict: verdict
            )
        }
    }

    private func deleteFood(_ entry: FoodEntry) {
        Task {
            await DayCoordinator.shared.deleteFoodEntry(
                entryID: entry.id,
                dayKey: today?.dayKey ?? Date().dayKey
            )
        }
    }
}

private struct FoodFeedback: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct FoodScoreSummary: View {
    let score: Int?
    let summary: String?
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Food score")
                        .font(.subheadline.weight(.semibold))
                    Text("So far today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let score {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(score)")
                            .font(.title.bold())
                            .monospacedDigit()
                        Text(FoodScoreBand.classify(score).rawValue)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(scoreColor(score))
                    }
                } else {
                    Text(isCurrent ? "Unavailable" : "Calculating…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch FoodScoreBand.classify(score) {
        case .good: .green
        case .bad: .orange
        case .ugly: .red
        }
    }
}

/// Styled like a clinical chart note: a colored severity stripe, a small-caps
/// context label, and the diagnosis itself in a serif face — deliberately
/// unflashy, no emoji, no cheerful heading.
private struct LatestMessageCard: View {
    let record: CheckInRecord

    private var accentColor: Color { record.met ? .green : .orange }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: record.kind == .sleep ? "moon.zzz.fill" : "drop.fill")
                        .font(.caption2)
                    Text("\(record.window.label) · \(record.kind == .sleep ? "Sleep" : "Water")")
                        .font(.caption.weight(.semibold))
                        .tracking(0.4)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.secondary)

                Text(record.message)
                    .font(.system(.body, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)

            Spacer(minLength: 0)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator, lineWidth: 0.5))
    }
}

private struct CheckInTimeline: View {
    let checkIns: [CheckInRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chart")
                .font(.headline)
            ForEach(checkIns) { record in
                HStack(spacing: 10) {
                    Image(systemName: record.kind == .sleep ? "moon.zzz.fill" : "drop.fill")
                        .foregroundStyle(record.kind == .sleep ? .indigo : .cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(record.window.label) · \(record.met ? "Cleared" : "Flagged")")
                            .font(.caption.weight(.semibold))
                        Text(record.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
