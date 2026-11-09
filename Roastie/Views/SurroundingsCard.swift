import SwiftUI

struct SurroundingsCard: View {
    let weather: SurroundingsWeather?
    let isLoading: Bool
    let statusMessage: String?
    let bonusEarnedAt: Date?
    let onRefresh: () -> Void
    let onComplete: () async -> Bool
    @State private var isSaving = false
    @State private var saveError = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let suggestion = weather.flatMap { SurroundingsSuggestion.make(weather: $0, now: context.date) }
            let earnedToday = bonusEarnedAt.map { Calendar.current.isDate($0, inSameDayAs: context.date) } ?? false
            VStack(alignment: .leading, spacing: 12) {
                Label("Surroundings today", systemImage: "cloud.sun")
                    .font(.headline)
                if let weather, let suggestion {
                    Text("Nearby · \(weather.temperatureC.formatted(.number.precision(.fractionLength(0))))°C · feels like \(weather.apparentTemperatureC.formatted(.number.precision(.fractionLength(0))))°C")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(suggestion.title).font(.subheadline.weight(.semibold))
                    Text(suggestion.detail).font(.subheadline)
                    if earnedToday {
                        Label("Suggestion bonus +1 today", systemImage: "checkmark.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DrJayTheme.primary)
                    } else {
                        Button {
                            guard !isSaving else { return }
                            isSaving = true
                            saveError = false
                            Task {
                                // Recheck freshness at the tap, not just at the last timeline update.
                                if weather.isUsable(at: .now) {
                                    saveError = !(await onComplete())
                                } else {
                                    saveError = true
                                }
                                isSaving = false
                            }
                        } label: {
                            Label(isSaving ? "Saving…" : "I followed this suggestion", systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSaving)
                    }
                    Text("Updated \(weather.observedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Check nearby weather for an optional food or hydration idea.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if earnedToday {
                        Text("Suggestion bonus +1 today").font(.subheadline.weight(.semibold))
                    }
                }
                if let statusMessage {
                    Text(statusMessage).font(.caption).foregroundStyle(.secondary)
                }
                if saveError {
                    Text("Couldn’t save a bonus. Check fresh weather and try again.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button(action: onRefresh) {
                    Label(isLoading ? "Checking…" : "Check Weather", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || isSaving)
                Text("Optional · At most +1 per day, separate from your score. No penalty for skipping. Goals and core verdict stay unchanged. Follow your personal fluid and dietary guidance.")
                    .font(.caption).foregroundStyle(.secondary)
                Link("Weather by Open-Meteo · CC BY 4.0", destination: URL(string: "https://open-meteo.com/")!)
                    .font(.caption)
            }
            .tint(DrJayTheme.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .clinicalCard()
        }
    }
}
