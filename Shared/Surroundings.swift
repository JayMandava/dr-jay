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

    /// Optional choices; no allergy or diet profile is inferred.
    var foodPointers: [String] {
        switch kind {
        case .warm, .humid:
            return [
                "Try cucumber or watermelon with a meal or snack.",
                "Choose curd or an unsweetened dairy-free alternative if it suits you.",
                "Keep a familiar meal balanced: rice or roti, dal and vegetables.",
                "Keep perishable foods chilled until you eat."
            ]
        case .cool:
            return [
                "Try a warm vegetable or lentil soup.",
                "Choose porridge or oats for a warm, easy meal.",
                "Pair rice or roti with dal and cooked vegetables.",
                "Add a fruit you enjoy as an optional snack."
            ]
        case .wet:
            return [
                "Try a simple home meal such as khichdi with vegetables.",
                "Use beans or lentils for an easy protein option.",
                "Add cooked vegetables or washed fruit you enjoy.",
                "Keep leftovers chilled and reheat them thoroughly."
            ]
        case .mild:
            return [
                "Build a meal around rice or roti, dal and vegetables.",
                "Choose a fruit you enjoy for a snack.",
                "Try beans, lentils or another familiar protein with your meal.",
                "Prepare a simple meal ahead if your day is busy."
            ]
        }
    }

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

/// Read-only progress against the existing goal, never a weather-adjusted target.
struct SurroundingsHydration: Equatable, Sendable {
    let goalBottles: Int
    let bottlesLogged: Int
    let bottleSizeMl: Int

    var remainingBottles: Int {
        max(0, max(0, goalBottles) - max(0, bottlesLogged))
    }

    var title: String {
        guard goalBottles > 0 else { return "Check your water goal in Settings" }
        guard remainingBottles > 0 else { return "Your water goal is met today" }
        let unit = remainingBottles == 1 ? "bottle" : "bottles"
        // Invalid imported settings must not invent a volume or overflow.
        let (volume, overflow) = remainingBottles.multipliedReportingOverflow(by: bottleSizeMl)
        let amount = bottleSizeMl > 0 && !overflow ? " (\(volume) ml)" : ""
        return "\(remainingBottles) \(unit) left today\(amount)"
    }

    var detail: String {
        guard goalBottles > 0 else { return "Use your personal fluid guidance." }
        guard remainingBottles > 0 else { return "Weather hasn’t increased your goal. Follow your personal fluid guidance." }
        let size = bottleSizeMl > 0 ? " · \(bottleSizeMl) ml each" : ""
        return "\(max(0, bottlesLogged)) of \(goalBottles) bottles logged\(size). Spread the remainder through the day as suits you."
    }
}
