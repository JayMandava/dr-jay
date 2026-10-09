import AppIntents
import SwiftUI
import WidgetKit

struct AddHourSleepWidget: Widget {
    let kind = "AddHourSleepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            QuickLogWidgetView(snapshot: entry.snapshot, date: entry.date, action: .sleep, intent: AddHourSleepWidgetIntent())
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
            QuickLogWidgetView(snapshot: entry.snapshot, date: entry.date, action: .water, intent: LogBottleWidgetIntent())
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
    var kind: CheckKind { self == .sleep ? .sleep : .water }

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
    let date: Date
    let action: QuickLogAction
    let intent: Intent

    private var lastSaved: Date? {
        guard let saved = QuickLogReceipt.date(for: action.kind),
              saved <= date, saved.dayKey == date.dayKey,
              snapshot.dayKey == date.dayKey else { return nil }
        return saved
    }

    private var confirmation: String? {
        lastSaved.map {
            let time = $0.formatted(date: .omitted, time: .shortened)
            return action == .sleep ? "Last +1h · \(time)" : "Last bottle · \(time)"
        }
    }

    private var feedbackIcon: String {
        lastSaved == nil ? action.icon : "checkmark.circle.fill"
    }

    var body: some View {
        Button(intent: intent) {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: feedbackIcon)
                        .contentTransition(.symbolEffect(.replace))
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
                        .contentTransition(.numericText())
                        .invalidatableContent()
                    if let confirmation {
                        Label(confirmation, systemImage: "checkmark")
                            .font(.caption2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            default:
                VStack(spacing: 6) {
                    Image(systemName: feedbackIcon)
                        .contentTransition(.symbolEffect(.replace))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(action.color)
                        .frame(width: 44, height: 44)
                        .background(action.color.opacity(0.14), in: Circle())
                    Text(action.title)
                        .font(.headline)
                        .foregroundStyle(action.color)
                    Text(action.progress(snapshot: snapshot))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .invalidatableContent()
                    if let confirmation {
                        Text(confirmation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
        .accessibilityHint([action.progress(snapshot: snapshot), confirmation].compactMap { $0 }.joined(separator: ". "))
    }
}
