import SwiftUI
import SwiftData

struct TodayView: View {
    @Binding var settings: AppSettings
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @State private var showSettings = false
    @State private var showSleepSheet = false
    @State private var isLoggingWater = false

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
                            subtitle: GoalCalculator.sleepDetail(hours: today?.sleepHours)
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

                    NavigationLink {
                        HistoryView()
                    } label: {
                        HStack {
                            Label(currentStreakLabel, systemImage: "flame.fill")
                                .foregroundStyle(.orange)
                            Spacer()
                            Text("Best \(streakStats.longest)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

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
                LogSleepSheet(currentTotal: today?.sleepHours) { hours in
                    Task { await DayCoordinator.shared.logSleepHours(hours) }
                }
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
