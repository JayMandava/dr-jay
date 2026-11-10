import SwiftUI

struct SurroundingsCard: View {
    let weather: SurroundingsWeather?
    let isLoading: Bool
    let statusMessage: String?
    let waterBonusEarnedAt: Date?
    let waterPending: Bool
    let foodPicks: Set<Int>
    let hydration: SurroundingsHydration
    let onRefresh: () -> Void
    let onPickFood: (Int) async -> Bool
    @State private var isSaving = false
    @State private var saveError = false
    @State private var showFoodIdeas = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let suggestion = weather.flatMap { SurroundingsSuggestion.make(weather: $0, now: context.date) }
            let waterEarned = waterBonusEarnedAt.map { Calendar.current.isDate($0, inSameDayAs: context.date) } ?? false
            let bonusToday = (waterEarned ? 1 : 0) + foodPicks.count
            VStack(alignment: .leading, spacing: 12) {
                Label("Surroundings today", systemImage: "cloud.sun")
                    .font(.headline)
                if let weather, let suggestion {
                    Text("Nearby · \(weather.temperatureC.formatted(.number.precision(.fractionLength(0))))°C · feels like \(weather.apparentTemperatureC.formatted(.number.precision(.fractionLength(0))))°C")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(hydration.title).font(.subheadline.weight(.semibold))
                    Text(hydration.detail).font(.subheadline)
                    if waterEarned {
                        Label("Water bonus +1 earned", systemImage: "checkmark.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DrJayTheme.primary)
                    } else if waterPending {
                        Text("Finish these bottles to earn +1.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    DisclosureGroup(isExpanded: $showFoodIdeas) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(suggestion.foodPointers(in: weather.region).enumerated()), id: \.offset) { slot, pointer in
                                let picked = foodPicks.contains(slot)
                                Button {
                                    pick(slot, weather: weather, alreadyPicked: picked)
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(picked ? DrJayTheme.primary : Color.secondary)
                                        Text(pointer)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isSaving)
                                .accessibilityAddTraits(picked ? .isSelected : [])
                                .accessibilityHint(picked ? "Already counted today" : "Counts this idea as followed")
                            }
                            Text("Tap an idea you followed to earn +1. Examples only; check ingredients against your diet and allergies.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let tip = suggestion.safetyTip {
                                Text(tip).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("Food ideas near you").font(.subheadline.weight(.semibold))
                    }
                    Text("Updated \(weather.observedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Check weather for a food or hydration idea.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if bonusToday > 0 {
                        Text("Bonus today +\(bonusToday)").font(.subheadline.weight(.semibold))
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
                Text("Optional · Up to +4 a day: water +1, food ideas +1 each. Separate from your score. Follow your personal fluid and dietary guidance.")
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

    private func pick(_ slot: Int, weather: SurroundingsWeather, alreadyPicked: Bool) {
        guard !alreadyPicked, !isSaving else { return }
        isSaving = true
        saveError = false
        Task {
            // Recheck freshness at the tap, not just at the last timeline update.
            if weather.isUsable(at: .now) {
                saveError = !(await onPickFood(slot))
            } else {
                saveError = true
            }
            isSaving = false
        }
    }
}

/// Kept apart from TodayView's long modifier chain, which the type checker struggles with.
struct SurroundingsWaterWatcher: ViewModifier {
    let snapshot: SurroundingsWeather?
    let waterLogged: Int?
    let onSnapshot: (SurroundingsWeather?) -> Void
    let onWaterLogged: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: snapshot) { _, new in onSnapshot(new) }
            .onChange(of: waterLogged) { _, _ in onWaterLogged() }
    }
}
