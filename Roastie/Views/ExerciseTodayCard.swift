import SwiftUI

struct ExerciseTodayCard: View {
    let summary: ExerciseSummary
    let onLogExercise: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Exercise today", systemImage: "figure.run")
                    .font(.headline)
                Spacer()
                Button(action: onLogExercise) {
                    Label("Log Exercise", systemImage: "figure.run")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glass)
                .tint(DrJayTheme.primary)
            }

            if summary.entryCount == 0 {
                Text("Optional. Log movement when there is something worth recording.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(summary.entryCount) session\(summary.entryCount == 1 ? "" : "s")")
                        .font(.title3.bold())
                    Spacer()
                    if let minutes = summary.scoredMinutes {
                        Text("\(minutes) min")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(DrJayTheme.primary)
                    }
                }
                if summary.scoredEntryCount < summary.entryCount {
                    Text("Entries without explicit minutes are saved but do not affect the score.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .clinicalCard()
    }
}
