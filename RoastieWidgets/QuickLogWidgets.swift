import AppIntents
import SwiftUI
import WidgetKit

struct AddHourSleepWidget: Widget {
    let kind = "AddHourSleepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            QuickLogWidgetView(snapshot: entry.snapshot, action: .sleep, intent: AddHourSleepWidgetIntent())
                .containerBackground(DrJayTheme.surface, for: .widget)
        }
        .configurationDisplayName("Add 1h Sleep")
        .description("Tap to add one hour to today's sleep total without opening Dr Jay.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct LogBottleWidget: Widget {
    let kind = "LogBottleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            QuickLogWidgetView(snapshot: entry.snapshot, action: .water, intent: LogBottleWidgetIntent())
                .containerBackground(DrJayTheme.surface, for: .widget)
        }
        .configurationDisplayName("Log 1 Bottle")
        .description("Tap to log one finished bottle without opening Dr Jay.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

private enum QuickLogAction {
    case sleep, water

    var title: String { self == .sleep ? "Add 1h Sleep" : "Log 1 Bottle" }
    var icon: String { self == .sleep ? "moon.zzz.fill" : "drop.fill" }
    var color: Color { self == .sleep ? DrJayTheme.sleep : DrJayTheme.water }
    var increment: String { self == .sleep ? "+1h" : "+1" }

    func progress(snapshot: TodaySnapshot) -> String {
        let today = snapshot.dayKey == Date().dayKey ? snapshot : nil
        switch self {
        case .sleep:
            return today?.sleepHours.map { String(format: "%.1fh today", $0) } ?? "No sleep logged today"
        case .water:
            let goal = today?.waterGoalBottles ?? SharedStore.loadSettings().waterGoalBottles
            return "\(today?.waterBottlesLogged ?? 0) of \(goal) bottles today"
        }
    }
}

private struct QuickLogWidgetView<Intent: AppIntent>: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: TodaySnapshot
    let action: QuickLogAction
    let intent: Intent

    var body: some View {
        Button(intent: intent) {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: action.icon)
                    Text(action.increment)
                        .font(.caption2.weight(.semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 4) {
                    Label(action.title, systemImage: action.icon)
                        .font(.headline)
                    Text(action.progress(snapshot: snapshot))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            default:
                VStack(spacing: 10) {
                    Image(systemName: action.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(action.color)
                        .frame(width: 52, height: 52)
                        .background(action.color.opacity(0.14), in: Circle())
                    Text(action.title)
                        .font(.headline)
                        .foregroundStyle(action.color)
                    Text(action.progress(snapshot: snapshot))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.progress(snapshot: snapshot))
    }
}
