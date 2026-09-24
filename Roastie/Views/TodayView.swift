import SwiftUI
import SwiftData

struct TodayView: View {
    @Binding var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @State private var showSettings = false
    @State private var showSleepSheet = false
    @State private var showFoodSheet = false
    @State private var isLoggingWater = false
    @State private var loggedFoodResult: FoodEntry?
    @State private var foodFeedback: FoodFeedback?
    @State private var stepCount: Int?
    @State private var isLoadingSteps = false
    @State private var stepLoadFinished = false

    private var today: DailyLog? { logs.first { $0.dayKey == Date().dayKey } }
    private var streakStats: StreakStats { StreakCalculator.calculate(logs: logs) }

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

                    FoodScoreCard(
                        score: today?.foodScore,
                        summary: today?.foodScoreSummary,
                        isCurrent: today?.foodScoreIsCurrent == true,
                        hasEntries: !(today?.foodEntries ?? []).isEmpty,
                        onLogFood: {
                            Haptics.tap()
                            showFoodSheet = true
                        }
                    )

                    StepCountCard(
                        stepCount: stepCount,
                        isLoading: isLoadingSteps,
                        loadFinished: stepLoadFinished,
                        onConnect: connectSteps
                    )

                    if Calendar.current.component(.hour, from: .now) >= 22 {
                        DailySummaryCard(result: dailySummary)
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
                await refreshSteps()
            }
            .refreshable {
                await DayCoordinator.shared.refreshToday()
                await refreshSteps()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshSteps() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthStepCountDidChange)) { _ in
                Task { await refreshSteps() }
            }
        }
    }

    private var dailySummary: DailySummaryResult {
        DailySummaryCalculator.calculate(DailySummaryInput(
            sleepHours: today?.sleepHours,
            waterBottlesLogged: today?.waterBottlesLogged ?? 0,
            waterGoalBottles: today?.waterGoalBottles ?? settings.waterGoalBottles,
            foodScore: today?.foodScoreIsCurrent == true ? today?.foodScore : nil,
            steps: stepCount
        ))
    }

    private func refreshSteps() async {
        guard HealthKitManager.shared.isAvailable else {
            stepLoadFinished = true
            return
        }
        isLoadingSteps = true
        defer {
            isLoadingSteps = false
            stepLoadFinished = true
        }
        do {
            stepCount = try await HealthKitManager.shared.stepsToday()
        } catch {
            AppLogger.report(error, operation: "Read steps for Today", logger: AppLogger.health)
            stepCount = nil
        }
    }

    private func connectSteps() {
        Task {
            isLoadingSteps = true
            do {
                try await HealthKitManager.shared.requestStepAuthorization()
            } catch {
                AppLogger.report(error, operation: "Request step access", logger: AppLogger.health)
            }
            await refreshSteps()
            await DayCoordinator.shared.refreshToday()
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
                message: "Dr Jay couldn’t analyse this entry on this device. You can classify it from History."
            )
        case .healthy:
            break
        }
    }
}

private struct StepCountCard: View {
    let stepCount: Int?
    let isLoading: Bool
    let loadFinished: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.walk")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.mint)
                .frame(width: 42, height: 42)
                .background(.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("Steps today")
                    .font(.headline)
                if let stepCount {
                    Text(stepCount.formatted())
                        .font(.title2.bold().monospacedDigit())
                } else if isLoading || !loadFinished {
                    Text("Reading Health…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No readable step data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("From Health · Not stored by Dr Jay")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if stepCount == nil, loadFinished, !isLoading {
                Button("Connect", action: onConnect)
                    .buttonStyle(.bordered)
                    .tint(.mint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator, lineWidth: 0.5))
    }
}

private struct DailySummaryCard: View {
    let result: DailySummaryResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily report", systemImage: "chart.bar.doc.horizontal")
                    .font(.headline)
                Spacer()
                Text("\(result.score)/100")
                    .font(.title3.bold().monospacedDigit())
            }

            Text(result.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Dr Jay")
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(result.roast)
                .font(.system(.subheadline, design: .serif))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator, lineWidth: 0.5))
    }
}

private struct FoodFeedback: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct FoodScoreCard: View {
    let score: Int?
    let summary: String?
    let isCurrent: Bool
    let hasEntries: Bool
    let onLogFood: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Food today", systemImage: "fork.knife")
                    .font(.headline)

                Spacer()

                Button(action: onLogFood) {
                    Label("Log Food", systemImage: "fork.knife")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 9)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(PressableButtonStyle())
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .background(.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.green)
            }

            if hasEntries {
                if let score {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(score)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("/100")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(FoodScoreBand.classify(score).rawValue.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(scoreColor(score))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(scoreColor(score).opacity(0.14), in: Capsule())
                    }
                } else {
                    HStack(spacing: 8) {
                        if !isCurrent {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isCurrent ? "Score unavailable" : "Calculating score…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if let presentedSummary {
                    Divider()

                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(score.map { scoreColor($0) } ?? Color.secondary)
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dr Jay")
                                .font(.caption2.weight(.semibold))
                                .tracking(0.5)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            Text(presentedSummary)
                                .font(.system(.subheadline, design: .serif))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text("Log what you eat. Dr Jay will handle the diagnosis.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator, lineWidth: 0.5))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch FoodScoreBand.classify(score) {
        case .good: .green
        case .bad: .orange
        case .ugly: .red
        }
    }

    private var presentedSummary: String? {
        guard let summary else { return nil }
        var result = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return nil }

        for band in ["Good", "Bad", "Ugly"] {
            for separator in [":", " —", " –", " -", "."] {
                let prefix = band + separator
                if result.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil {
                    result = String(result.dropFirst(prefix.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return result.isEmpty ? nil : result
                }
            }
        }
        return result
    }
}

/// Styled like a clinical chart note: a colored severity stripe, Dr Jay as the
/// consistent author, and compact context metadata beside it.
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
                HStack(spacing: 8) {
                    Text("Dr Jay")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.4)
                        .textCase(.uppercase)

                    Spacer()

                    Label(
                        "\(record.window.label) · \(record.kind == .sleep ? "Sleep" : "Water")",
                        systemImage: record.kind == .sleep ? "moon.zzz.fill" : "drop.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.09), in: Capsule())
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
