import Foundation

/// Ephemeral weather only. Never put coordinates or weather in health logs or model prompts.
struct SurroundingsWeather: Equatable, Sendable {
    let temperatureC: Double
    let apparentTemperatureC: Double
    let humidityPercent: Double
    let weatherCode: Int
    let observedAt: Date

    func isUsable(at now: Date) -> Bool {
        let age = now.timeIntervalSince(observedAt)
        return temperatureC.isFinite && (-90...60).contains(temperatureC)
            && apparentTemperatureC.isFinite && (-100...80).contains(apparentTemperatureC)
            && humidityPercent.isFinite && (0...100).contains(humidityPercent)
            && age >= 0 && age < 30 * 60
            && Calendar.current.isDate(observedAt, inSameDayAs: now)
    }
}

/// Product suggestions, not diagnoses, weather warnings, or a prescription to drink more.
/// Intentionally separate from GoalCalculator and DailySummaryCalculator.
struct SurroundingsSuggestion: Equatable, Sendable {
    enum Kind: String, Sendable { case warm, humid, cool, wet, mild }
    let kind: Kind
    let title: String
    let detail: String

    static func make(weather: SurroundingsWeather, now: Date = .now) -> Self? {
        guard weather.isUsable(at: now) else { return nil }
        if weather.apparentTemperatureC >= 28 || weather.temperatureC >= 30 {
            return Self(kind: .warm, title: "Keep it comfortable",
                        detail: "Warm outside? Keep water handy and sip as suits you.")
        }
        if weather.humidityPercent >= 75 && weather.temperatureC >= 24 {
            return Self(kind: .humid, title: "A little breathing room",
                        detail: "Warm and humid? Try a cool spot for your next meal.")
        }
        if weather.temperatureC <= 10 {
            return Self(kind: .cool, title: "Something warm, if you fancy",
                        detail: "Cool outside? Soup or a warm non-alcoholic drink might be welcome.")
        }
        if [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99].contains(weather.weatherCode) {
            return Self(kind: .wet, title: "An easy indoor option",
                        detail: "Wet outside? Keep it simple with a familiar meal at home.")
        }
        return Self(kind: .mild, title: "Keep the basics easy",
                    detail: "Mild outside. Make time for a regular meal.")
    }
}
