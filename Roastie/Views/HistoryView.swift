import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]

    var body: some View {
        List(logs) { log in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                    Text("\(GoalCalculator.sleepDetail(hours: log.sleepHours)) · \(GoalCalculator.waterDetail(bottlesLogged: log.waterBottlesLogged, goal: log.waterGoalBottles))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusIcon(log)
            }
        }
        .navigationTitle("History")
    }

    private func statusIcon(_ log: DailyLog) -> some View {
        let bothMet = log.sleepGoalMet == true && log.waterProgress >= 1
        return Image(systemName: bothMet ? "checkmark.circle.fill" : "flame.fill")
            .foregroundStyle(bothMet ? .green : .orange)
    }
}
