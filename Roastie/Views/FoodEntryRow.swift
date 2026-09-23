import SwiftUI

struct FoodEntryRow: View {
    let entry: FoodEntry
    let onMarkHealthy: () -> Void
    let onMarkUnhealthy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    Text("·")
                    Text(entry.verdict.label)
                        .foregroundStyle(statusColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let assessment = entry.assessment, !assessment.isEmpty {
                    Text(assessment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            Menu {
                Button("Mark Healthy", systemImage: "checkmark.circle") {
                    onMarkHealthy()
                }
                Button("Mark Unhealthy", systemImage: "exclamationmark.triangle") {
                    onMarkUnhealthy()
                }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIcon: String {
        switch entry.verdict {
        case .healthy: "checkmark.circle.fill"
        case .unhealthy: "exclamationmark.triangle.fill"
        case .unanalyzed: "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch entry.verdict {
        case .healthy: .green
        case .unhealthy: .orange
        case .unanalyzed: .secondary
        }
    }
}
