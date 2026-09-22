import SwiftUI

/// Free-form manual sleep entry — logged any time, additive, same as water:
/// each save adds to today's running total instead of replacing it. Useful
/// for logging in chunks (a nap, then last night's sleep) as the day goes.
struct LogSleepSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 1

    let currentTotal: Double?
    let onSave: (Double) -> Void

    private static let presets: [Double] = [0.5, 1, 2, 4, 6, 8]

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
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
                    .foregroundStyle(.indigo)

                Slider(value: $amount, in: 0.5...12, step: 0.5)
                    .tint(.indigo)
                    .padding(.horizontal, 32)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 10)], spacing: 10) {
                    ForEach(Self.presets, id: \.self) { preset in
                        presetButton(preset)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 32)
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
        .tint(preset == amount ? .indigo : .secondary)
    }
}
