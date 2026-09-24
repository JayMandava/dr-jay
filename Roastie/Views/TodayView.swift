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
    @State private var showDailyReport = false
    @State private var reportResult: DailySummaryResult?
    @State private var reportCommentary: String?
    @State private var isGeneratingReport = false

    private var today: DailyLog? { logs.first { $0.dayKey == Date().dayKey } }
    private var streakStats: StreakStats { StreakCalculator.calculate(logs: logs) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        RingView(
                            progress: today?.sleepProgress ?? 0,
                            color: DrJayTheme.clinicalBlue,
                            icon: "moon.zzz.fill",
                            title: "Sleep",
                            subtitle: sleepSubtitle
                        )
                        RingView(
                            progress: today?.waterProgress ?? 0,
                            color: DrJayTheme.frostBlue,
                            icon: "drop.fill",
                            title: "Water",
                            subtitle: GoalCalculator.waterDetail(bottlesLogged: today?.waterBottlesLogged ?? 0, goal: today?.waterGoalBottles ?? settings.waterGoalBottles)
                        )
                    }
                    .padding(.top, 8)

                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                Haptics.tap()
                                showSleepSheet = true
                            } label: {
                                Label("Log Sleep", systemImage: "moon.zzz.fill")
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                            .tint(DrJayTheme.clinicalBlue)

                            Button {
                                Haptics.tap()
                                isLoggingWater = true
                                Task {
                                    await DayCoordinator.shared.logWaterBottle()
                                    isLoggingWater = false
                                }
                            } label: {
                                Label(isLoggingWater ? "Logging…" : "Log Bottle", systemImage: "drop.fill")
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                            .tint(DrJayTheme.frostBlue)
                            .disabled(isLoggingWater)
                        }
                    }
                    .font(.subheadline.weight(.semibold))

                    if let latest = today?.checkIns.last {
                        LatestMessageCard(record: latest)
                            .id(latest.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

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

                    Button {
                        Haptics.tap()
                        showDailyReport = true
                        Task { await generateDailyReport() }
                    } label: {
                        Label("Generate Today’s Report", systemImage: "chart.bar.doc.horizontal")
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(DrJayTheme.clinicalBlue)

                    if Calendar.current.component(.hour, from: .now) >= 22 {
                        DailySummaryCard(result: dailySummary)
                    }

                    HStack {
                        Label(currentStreakLabel, systemImage: "flame.fill")
                            .foregroundStyle(DrJayTheme.amber)
                        Spacer()
                        Text("Best \(streakStats.longest)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(16)
                    .clinicalCard()

                    if let today, !today.checkIns.isEmpty {
                        CheckInTimeline(checkIns: today.checkIns.sorted { $0.timestamp > $1.timestamp })
                    }
                }
                .padding()
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: today?.checkIns.last?.id)
            }
            .background(DrJayTheme.canvas.ignoresSafeArea())
            .navigationTitle("Dr Jay")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("History")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .tint(DrJayTheme.clinicalBlue)
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
            .sheet(isPresented: $showDailyReport) {
                DailyReportSheet(
                    result: reportResult,
                    commentary: reportCommentary,
                    isGenerating: isGeneratingReport,
                    onRegenerate: {
                        Task { await generateDailyReport() }
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
        DailySummaryCalculator.calculate(dailySummaryInput)
    }

    private var dailySummaryInput: DailySummaryInput {
        DailySummaryInput(
            sleepHours: today?.sleepHours,
            waterBottlesLogged: today?.waterBottlesLogged ?? 0,
            waterGoalBottles: today?.waterGoalBottles ?? settings.waterGoalBottles,
            foodScore: today?.foodScoreIsCurrent == true ? today?.foodScore : nil,
            steps: stepCount
        )
    }

    private func generateDailyReport() async {
        guard !isGeneratingReport else { return }
        isGeneratingReport = true
        reportCommentary = nil

        await refreshSteps()
        let input = dailySummaryInput
        let result = DailySummaryCalculator.calculate(input)
        reportResult = result
        reportCommentary = await DailyReportGenerator.generate(
            input: input,
            result: result,
            intensity: settings.roastIntensity
        )
        isGeneratingReport = false
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
                .foregroundStyle(DrJayTheme.frostBlue)
                .frame(width: 42, height: 42)
                .background(DrJayTheme.frostBlue.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
                Text("Today · Apple Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if stepCount == nil, loadFinished, !isLoading {
                Button("Connect", action: onConnect)
                    .buttonStyle(.glass)
                    .tint(DrJayTheme.clinicalBlue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .clinicalCard()
    }
}

private struct DailyReportSheet: View {
    let result: DailySummaryResult?
    let commentary: String?
    let isGenerating: Bool
    let onRegenerate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let result {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(result.score)/100")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Spacer()
                                Text(result.band.rawValue.uppercased())
                                    .font(.caption.weight(.bold))
                                    .tracking(0.7)
                                    .foregroundStyle(bandColor(result.band))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(bandColor(result.band).opacity(0.14), in: Capsule())
                            }
                            Text(result.isComplete ? "Complete report" : "Incomplete report")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(result.isComplete ? DrJayTheme.clinicalBlue : DrJayTheme.amber)
                            Text(result.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation")
                                .font(.headline)
                            WeightRow(label: "Food", weight: "35%", icon: "fork.knife", color: DrJayTheme.clinicalBlue)
                            WeightRow(label: "Sleep", weight: "30%", icon: "moon.zzz.fill", color: DrJayTheme.clinicalBlue)
                            WeightRow(label: "Water", weight: "30%", icon: "drop.fill", color: DrJayTheme.frostBlue)
                            WeightRow(label: "Steps", weight: "5%", icon: "figure.walk", color: DrJayTheme.earth)
                            Text("Missing metrics are excluded and the available weights are proportionally normalized. Missing steps never reduce the score.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .clinicalCard()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dr Jay")
                            .font(.caption2.weight(.semibold))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)

                        if isGenerating {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Reviewing the chart…")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let commentary {
                            Text(commentary)
                                .font(.system(.body, design: .serif))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(DrJayTheme.amber.opacity(0.11), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(DrJayTheme.amber.opacity(0.28), lineWidth: 0.5)
                    }

                    Button(action: onRegenerate) {
                        Label("Generate Again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(DrJayTheme.clinicalBlue)
                    .disabled(isGenerating)
                }
                .padding()
            }
            .background(DrJayTheme.canvas.ignoresSafeArea())
            .navigationTitle("Today’s Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func bandColor(_ band: DailySummaryBand) -> Color {
        switch band {
        case .good: DrJayTheme.clinicalBlue
        case .bad: DrJayTheme.amber
        case .ugly: DrJayTheme.ugly
        }
    }
}

private struct WeightRow: View {
    let label: String
    let weight: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(color)
            Spacer()
            Text(weight)
                .font(.subheadline.bold().monospacedDigit())
        }
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
        .clinicalCard()
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
                        .padding(.vertical, 7)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glass)
                .tint(DrJayTheme.clinicalBlue)
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
        .clinicalCard()
    }

    private func scoreColor(_ score: Int) -> Color {
        switch FoodScoreBand.classify(score) {
        case .good: DrJayTheme.clinicalBlue
        case .bad: DrJayTheme.amber
        case .ugly: DrJayTheme.ugly
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

    private var accentColor: Color { record.met ? DrJayTheme.clinicalBlue : DrJayTheme.amber }

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
        .clinicalCard()
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
                        .foregroundStyle(record.kind == .sleep ? DrJayTheme.clinicalBlue : DrJayTheme.frostBlue)
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
