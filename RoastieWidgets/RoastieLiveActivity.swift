import ActivityKit
import WidgetKit
import SwiftUI

struct RoastieLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoastieActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    miniRing(progress: context.state.sleepProgress, color: .indigo, icon: "moon.zzz.fill")
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    miniRing(progress: context.state.waterProgress, color: .cyan, icon: "drop.fill")
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        HStack(spacing: 16) {
                            statusChip(label: "Sleep", icon: "moon.zzz.fill", wasRoast: context.state.sleepWasRoast)
                            statusChip(label: "Water", icon: "drop.fill", wasRoast: context.state.waterWasRoast)
                        }
                        Text("Next: \(context.state.nextCheckInLabel)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(context.state.sleepGoalMet == false ? .red : .indigo)
            } compactTrailing: {
                Text("\(context.state.waterBottlesLogged)/\(context.state.waterGoalBottles)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
            } minimal: {
                Image(systemName: context.state.latestWasRoastIcon)
            }
        }
    }

    private func miniRing(progress: Double, color: Color, icon: String) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(color)
        }
        .frame(width: 30, height: 30)
    }

    private func statusChip(label: String, icon: String, wasRoast: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2).foregroundStyle(wasRoast ? .orange : .green)
            Text("\(label) \(wasRoast ? "Flagged" : "Cleared")")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(wasRoast ? .orange : .green)
        }
    }
}

private extension RoastieActivityAttributes.ContentState {
    var latestWasRoastIcon: String {
        (sleepGoalMet == false || waterProgress < 0.5) ? "flame.fill" : "checkmark.circle.fill"
    }
}

private struct LockScreenView: View {
    let state: RoastieActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                ring(progress: state.sleepProgress, color: .indigo, icon: "moon.zzz.fill")
                Text(state.sleepHours.map { String(format: "%.1fh", $0) } ?? "–")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            VStack(spacing: 4) {
                ring(progress: state.waterProgress, color: .cyan, icon: "drop.fill")
                Text("\(state.waterBottlesLogged)/\(state.waterGoalBottles)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Next: \(state.nextCheckInLabel)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                statusRow(label: "Sleep", wasRoast: state.sleepWasRoast)
                statusRow(label: "Water", wasRoast: state.waterWasRoast)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    private func ring(progress: Double, color: Color, icon: String) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: icon).font(.caption2).foregroundStyle(color)
        }
        .frame(width: 40, height: 40)
    }

    private func statusRow(label: String, wasRoast: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: wasRoast ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.caption2)
                .foregroundStyle(wasRoast ? .orange : .green)
            Text("\(label): \(wasRoast ? "Flagged" : "Cleared")")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
        }
    }
}
