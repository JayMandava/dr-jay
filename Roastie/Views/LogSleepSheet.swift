import SwiftUI

/// Free-form manual sleep entry — logged any time, additive, same as water:
/// each save adds to today's running total instead of replacing it. Useful
/// for logging in chunks (a nap, then last night's sleep) as the day goes.
struct LogSleepSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 1
    @State private var isReplacingFromHealth = false
    @State private var healthKitError: String?

    let currentTotal: Double?
    let healthKitEnabled: Bool
    let onSave: (Double) -> Void
    let onReplaceWithHealth: () async -> Bool

    private static let presets: [Double] = [0.5, 1, 2, 4, 6, 8]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let currentTotal, currentTotal > 0 {
                        Text("\(String(format: "%.1f", currentTotal))h logged today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("+\(String(format: "%.1f", amount))h")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: amount)
                        .foregroundStyle(DrJayTheme.clinicalBlue)

                    Slider(value: $amount, in: 0.5...12, step: 0.5)
                        .tint(DrJayTheme.clinicalBlue)
                        .padding(.horizontal, 32)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 10)], spacing: 10) {
                        ForEach(Self.presets, id: \.self) { preset in
                            presetButton(preset)
                        }
                    }
                    .padding(.horizontal, 32)

                    if healthKitEnabled {
                        healthKitControls
                    }
                }
                .padding(.vertical, 24)
            }
            .background(DrJayTheme.canvas.ignoresSafeArea())
            .navigationTitle("Add Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Haptics.tap()
                        onSave(amount)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var healthKitControls: some View {
        VStack(spacing: 10) {
            Text("Adding sleep switches today to manual tracking. Health updates won't replace today's total.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    isReplacingFromHealth = true
                    healthKitError = nil
                    let replaced = await onReplaceWithHealth()
                    isReplacingFromHealth = false
                    if replaced {
                        dismiss()
                    } else {
                        healthKitError = "No sleep data is currently available in Health."
                    }
                }
            } label: {
                Label(
                    isReplacingFromHealth ? "Reading Health…" : "Replace with Health Data",
                    systemImage: "heart.text.square"
                )
            }
            .buttonStyle(.glass)
            .tint(DrJayTheme.clinicalBlue)
            .disabled(isReplacingFromHealth)

            if let healthKitError {
                Text(healthKitError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }

    private func presetButton(_ preset: Double) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.snappy) { amount = preset }
        } label: {
            Text(preset < 1 ? "\(Int(preset * 60))m" : "\(Int(preset))h")
                .font(.subheadline.weight(.medium))
                .frame(minWidth: 40)
        }
        .buttonStyle(.bordered)
        .tint(preset == amount ? DrJayTheme.clinicalBlue : Color.secondary)
    }
}
