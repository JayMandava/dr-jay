import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: SharedStore.loadSnapshot() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: SharedStore.loadSnapshot() ?? .placeholder)
        // The app pushes a fresh snapshot on every log/check-in; refresh
        // opportunistically every 30 minutes as a backstop.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct RoastieHomeWidget: Widget {
    let kind = "RoastieHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            RoastieWidgetView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Dr Jay")
        .description("Today's sleep and water progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct RoastieWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: TodaySnapshot

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Label("\(snapshot.waterBottlesLogged)/\(snapshot.waterGoalBottles)", systemImage: "drop.fill")
                    Label(sleepLabel, systemImage: "moon.zzz.fill")
                }
                .font(.caption.weight(.semibold))
                HStack(spacing: 10) {
                    statusChip(wasRoast: snapshot.sleepWasRoast, label: "Sleep")
                    statusChip(wasRoast: snapshot.waterWasRoast, label: "Water")
                }
            }
        case .systemMedium:
            HStack(spacing: 16) {
                rings
                VStack(alignment: .leading, spacing: 10) {
                    statusRow(icon: "moon.zzz.fill", wasRoast: snapshot.sleepWasRoast, value: sleepLabel)
                    statusRow(icon: "drop.fill", wasRoast: snapshot.waterWasRoast, value: "\(snapshot.waterBottlesLogged)/\(snapshot.waterGoalBottles) bottles")
                }
            }
            .padding(4)
        default:
            VStack(spacing: 8) {
                rings
                HStack(spacing: 10) {
                    statusChip(wasRoast: snapshot.sleepWasRoast, label: sleepLabel)
                    statusChip(wasRoast: snapshot.waterWasRoast, label: "\(snapshot.waterBottlesLogged)/\(snapshot.waterGoalBottles)")
                }
            }
            .padding(4)
        }
    }

    private func statusRow(icon: String, wasRoast: Bool, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(wasRoast ? .orange : .green)
            Text(value).font(.caption.weight(.semibold))
            Spacer(minLength: 4)
            Image(systemName: wasRoast ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.caption2)
                .foregroundStyle(wasRoast ? .orange : .green)
        }
    }

    private func statusChip(wasRoast: Bool, label: String) -> some View {
        Label(label, systemImage: wasRoast ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(wasRoast ? .orange : .green)
    }

    private var sleepLabel: String {
        snapshot.sleepHours.map { String(format: "%.1fh", $0) } ?? "–"
    }

    private var rings: some View {
        HStack(spacing: 10) {
            miniRing(progress: snapshot.sleepProgress, color: .indigo, icon: "moon.zzz.fill")
            miniRing(progress: snapshot.waterProgress, color: .cyan, icon: "drop.fill")
        }
    }

    private func miniRing(progress: Double, color: Color, icon: String) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: icon).font(.caption2).foregroundStyle(color)
        }
        .frame(width: 44, height: 44)
    }
}
