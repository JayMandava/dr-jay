import SwiftUI

struct FoodMemoriesView: View {
    @State private var memories: [FoodCorrectionMemory] = []

    var body: some View {
        List {
            if memories.isEmpty {
                ContentUnavailableView(
                    "No Food Memories",
                    systemImage: "brain.head.profile",
                    description: Text("Correct a food verdict in History and Dr Jay will remember it here.")
                )
            } else {
                Section {
                    ForEach(memories) { memory in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: memory.verdict == .healthy
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill")
                                .foregroundStyle(memory.verdict == .healthy ? DrJayTheme.primary : DrJayTheme.roast)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(memory.displayText)
                                    .font(.subheadline.weight(.medium))
                                Text("\(memory.verdict.label) · Remembered \(memory.correctedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: forget)
                } footer: {
                    Text("Exact matches use your verdict automatically. Similar foods are only shown to the on-device model as context.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DrJayTheme.canvas)
        .navigationTitle("Food Memories")
        .tint(DrJayTheme.primary)
        .onAppear(perform: reload)
    }

    private func reload() {
        memories = SharedStore.loadFoodCorrectionMemories()
            .sorted { $0.correctedAt > $1.correctedAt }
    }

    private func forget(at offsets: IndexSet) {
        let ids = offsets.map { memories[$0].id }
        for id in ids {
            DayCoordinator.shared.forgetFoodCorrectionMemory(id: id)
        }
        memories.remove(atOffsets: offsets)
    }
}
