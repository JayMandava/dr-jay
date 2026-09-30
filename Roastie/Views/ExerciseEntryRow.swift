import SwiftUI

struct ExerciseEntryRow: View {
    let entry: ExerciseEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.text)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text(entry.category.label)
                if let minutes = entry.durationMinutes {
                    Text("·")
                    Text("\(minutes) min")
                } else {
                    Text("· Duration not provided")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
