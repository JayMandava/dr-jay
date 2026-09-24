import SwiftUI

struct LogFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var description = ""
    @State private var isLogging = false

    let onSave: (String) async -> FoodEntry?
    let onLogged: (FoodEntry) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("What did you eat?")
                    .font(.headline)

                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Example: 2 dosas with chutney and coffee")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $description)
                        .focused($isFocused)
                        .frame(minHeight: 130)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                }
                .background(DrJayTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DrJayTheme.outline.opacity(0.7), lineWidth: 0.5)
                }

                Label(
                    "Food is assessed on this device. Nothing is sent elsewhere.",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .background(DrJayTheme.canvas.ignoresSafeArea())
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isLogging)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLogging ? "Checking…" : "Log & Check") {
                        isLogging = true
                        Task {
                            if let entry = await onSave(description) {
                                onLogged(entry)
                                dismiss()
                            } else {
                                isLogging = false
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLogging)
                }
            }
            .onAppear { isFocused = true }
            .tint(DrJayTheme.primary)
        }
        .interactiveDismissDisabled(isLogging)
        .presentationDetents([.medium])
    }
}
