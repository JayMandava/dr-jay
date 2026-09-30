import SwiftUI

struct LogExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var description = ""
    @State private var isLogging = false

    let onSave: (String) async -> ExerciseEntry?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("What exercise did you do?")
                    .font(.headline)

                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Example: 30-minute run or played badminton for 1 hour")
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
                    "Optional. Only minutes written explicitly are reflected in today’s Movement score.",
                    systemImage: "text.badge.checkmark"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .background(DrJayTheme.canvas.ignoresSafeArea())
            .navigationTitle("Log Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isLogging)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLogging ? "Logging…" : "Log Exercise") {
                        isLogging = true
                        Task {
                            if await onSave(description) != nil {
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
