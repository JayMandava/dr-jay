import Foundation

/// Ephemeral weather only. Never put coordinates or weather in health logs or model prompts.
struct SurroundingsWeather: Equatable, Sendable {
    let temperatureC: Double
    let apparentTemperatureC: Double
    let humidityPercent: Double
    let weatherCode: Int
    let observedAt: Date
    /// Coarse area only, derived on device; coordinates are never kept.
    var region: SurroundingsRegion = .general

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

    /// Every weather group offers this many food ideas; each can be picked once a day.
    static let foodSlotCount = 3

    /// A food-safety reminder shown with the ideas, not something to pick.
    var safetyTip: String? {
        switch kind {
        case .warm, .humid: "Keep perishable foods chilled until you eat."
        case .wet: "Keep leftovers chilled and reheat them thoroughly."
        case .cool, .mild: nil
        }
    }

    /// Optional examples from the user's area; no allergy or diet profile is inferred.
    func foodPointers(in region: SurroundingsRegion) -> [String] {
        let food = region.foods
        switch kind {
        case .warm, .humid:
            return [
                "Try \(food.produce) with a meal or snack.",
                "Keep a familiar meal balanced: \(food.homeMeal).",
                "Add \(food.fruit) as a cool snack."
            ]
        case .cool:
            return [
                "Try \(food.warmDish).",
                "Build a warm meal around \(food.homeMeal).",
                "Add \(food.fruit) as an optional snack."
            ]
        case .wet:
            return [
                "Keep it simple at home with \(food.homeMeal).",
                "Use \(food.protein) for an easy protein option.",
                "Add \(food.fruit) as an easy snack."
            ]
        case .mild:
            return [
                "Build a meal around \(food.homeMeal).",
                "Choose \(food.fruit) for a snack.",
                "Try \(food.protein) with your meal."
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

/// Coarse area used only to pick familiar example foods. Boxes are approximate
/// on purpose: a border town may get its neighbour's examples, which is harmless.
enum SurroundingsRegion: Equatable, Sendable {
    case southAsia, eastAsia, southeastAsia, middleEastNorthAfrica, europe
    case subSaharanAfrica, northAmerica, latinAmerica, oceania, general

    init(latitude: Double, longitude: Double) {
        func inside(_ lat: ClosedRange<Double>, _ lon: ClosedRange<Double>) -> Bool {
            lat.contains(latitude) && lon.contains(longitude)
        }
        if inside(5 ... 37, 60 ... 92) { self = .southAsia }
        else if inside(22 ... 54, 100 ... 146) { self = .eastAsia }
        else if inside(-11 ... 22, 92 ... 141) { self = .southeastAsia }
        else if inside(12 ... 36, -18 ... 60) { self = .middleEastNorthAfrica }
        else if inside(36 ... 72, -25 ... 45) { self = .europe }
        else if inside(-35 ... 12, -18 ... 52) { self = .subSaharanAfrica }
        else if inside(24 ... 84, -168 ... -52) { self = .northAmerica }
        else if inside(-56 ... 24, -120 ... -34) { self = .latinAmerica }
        else if inside(-44 ... -10, 112 ... 154) || inside(-47 ... -34, 166 ... 179) { self = .oceania }
        else { self = .general }
    }

    struct Foods {
        let produce: String
        let warmDish: String
        let homeMeal: String
        let protein: String
        let fruit: String
    }

    var foods: Foods {
        switch self {
        case .southAsia:
            Foods(produce: "cucumber or watermelon", warmDish: "a vegetable or lentil soup",
                  homeMeal: "rice or roti with dal and vegetables", protein: "dal, chickpeas or beans",
                  fruit: "banana or guava")
        case .eastAsia:
            Foods(produce: "cucumber or winter melon", warmDish: "miso, congee or a clear vegetable soup",
                  homeMeal: "rice or noodles with vegetables and tofu, egg or fish",
                  protein: "tofu, edamame or fish", fruit: "pear or mandarin")
        case .southeastAsia:
            Foods(produce: "cucumber or pineapple", warmDish: "a light vegetable or noodle soup",
                  homeMeal: "rice with stir-fried vegetables and fish, egg or tofu",
                  protein: "tofu, tempeh or fish", fruit: "banana or papaya")
        case .middleEastNorthAfrica:
            Foods(produce: "cucumber, tomato or melon", warmDish: "a lentil or vegetable soup",
                  homeMeal: "rice or flatbread with vegetables and chickpeas",
                  protein: "chickpeas, lentils or fish", fruit: "dates or oranges")
        case .europe:
            Foods(produce: "a crisp salad or melon", warmDish: "a vegetable or bean soup",
                  homeMeal: "potatoes, pasta or wholegrain bread with vegetables",
                  protein: "beans, eggs or fish", fruit: "an apple or pear")
        case .subSaharanAfrica:
            Foods(produce: "cucumber or watermelon", warmDish: "a vegetable or bean stew",
                  homeMeal: "maize, cassava or rice with beans and greens",
                  protein: "beans, lentils or fish", fruit: "mango or banana")
        case .northAmerica:
            Foods(produce: "cucumber or melon", warmDish: "a vegetable or bean soup",
                  homeMeal: "wholegrain bread, rice or potatoes with vegetables",
                  protein: "beans, eggs or chicken", fruit: "an apple or berries")
        case .latinAmerica:
            Foods(produce: "cucumber or watermelon", warmDish: "a vegetable or bean soup",
                  homeMeal: "rice, corn tortillas or potatoes with beans and vegetables",
                  protein: "beans, eggs or fish", fruit: "banana or papaya")
        case .oceania:
            Foods(produce: "cucumber or watermelon", warmDish: "a vegetable soup",
                  homeMeal: "wholegrain bread, rice or potatoes with vegetables",
                  protein: "beans, eggs or fish", fruit: "an apple or citrus")
        case .general:
            Foods(produce: "cucumber or watermelon", warmDish: "a vegetable or bean soup",
                  homeMeal: "rice, bread or potatoes with vegetables",
                  protein: "beans, lentils or eggs", fruit: "a fruit you enjoy")
        }
    }
}
