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
    func foodPointers(in region: SurroundingsRegion, on date: Date, calendar: Calendar = .current) -> [String] {
        // Gregorian civil days in the user's time zone: stable across renders,
        // refreshes and relaunches, including DST and year boundaries. Do not use
        // hashValue (changes per process), random(), or the weather fetch time.
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = calendar.timeZone
        let components = localCalendar.dateComponents([.era, .year, .month, .day], from: date)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // Normalize the local civil date to UTC before counting days. Counting
        // elapsed seconds in the local zone would drift on 23/25-hour DST days.
        let civilDate = utcCalendar.date(from: components) ?? date
        let day = Int(floor(civilDate.timeIntervalSince1970 / 86_400))
        let options = region.foodOptions
        let food = options[(day % options.count + options.count) % options.count]
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

    /// Four sets of actual foods per region, rather than four phrasings of
    /// the same meal. Weather still chooses the suitable type of suggestion.
    var foodOptions: [Foods] {
        let alternatives: [Foods] = switch self {
        case .southAsia:
            [Foods(produce: "tomato or carrot", warmDish: "vegetable khichdi",
                   homeMeal: "roti with chickpeas and spinach", protein: "chickpeas or curd", fruit: "orange or apple"),
             Foods(produce: "cabbage or cucumber", warmDish: "sambar with vegetables",
                   homeMeal: "idli with sambar and vegetables", protein: "lentils or eggs", fruit: "papaya or pomegranate"),
             Foods(produce: "carrot or radish", warmDish: "a chickpea and vegetable stew",
                   homeMeal: "rice with rajma and greens", protein: "rajma or tofu", fruit: "pear or melon")]
        case .eastAsia:
            [Foods(produce: "tomato or carrot", warmDish: "a tofu and mushroom soup",
                   homeMeal: "rice with broccoli and egg", protein: "eggs or soybeans", fruit: "apple or kiwi"),
             Foods(produce: "cabbage or radish", warmDish: "a vegetable noodle broth",
                   homeMeal: "noodles with greens and edamame", protein: "tofu or chicken", fruit: "melon or grapes"),
             Foods(produce: "lettuce or cucumber", warmDish: "a pumpkin and bean soup",
                   homeMeal: "rice with mushrooms and fish", protein: "edamame or eggs", fruit: "orange or peach")]
        case .southeastAsia:
            [Foods(produce: "tomato or lettuce", warmDish: "a tofu and greens soup",
                   homeMeal: "rice with tempeh and greens", protein: "tempeh or eggs", fruit: "mango or orange"),
             Foods(produce: "carrot or cabbage", warmDish: "a pumpkin and lentil soup",
                   homeMeal: "noodles with vegetables and tofu", protein: "beans or fish", fruit: "guava or melon"),
             Foods(produce: "cucumber or radish", warmDish: "a fish and vegetable broth",
                   homeMeal: "rice with egg and cabbage", protein: "tofu or lentils", fruit: "dragon fruit or pineapple")]
        case .middleEastNorthAfrica:
            [Foods(produce: "carrot or lettuce", warmDish: "a chickpea and vegetable stew",
                   homeMeal: "couscous with chickpeas and carrots", protein: "beans or eggs", fruit: "apple or pear"),
             Foods(produce: "cabbage or radish", warmDish: "a white bean soup",
                   homeMeal: "bulgur with lentils and greens", protein: "lentils or yogurt", fruit: "grapes or melon"),
             Foods(produce: "tomato or cucumber", warmDish: "a barley and vegetable soup",
                   homeMeal: "flatbread with beans and salad", protein: "chickpeas or eggs", fruit: "mandarin or banana")]
        case .europe:
            [Foods(produce: "tomato or carrot", warmDish: "a lentil and carrot soup",
                   homeMeal: "rice with beans and greens", protein: "lentils or tofu", fruit: "orange or berries"),
             Foods(produce: "cabbage or radish", warmDish: "a mushroom and barley soup",
                   homeMeal: "pasta with chickpeas and spinach", protein: "chickpeas or eggs", fruit: "banana or grapes"),
             Foods(produce: "lettuce or cucumber", warmDish: "a pumpkin and lentil soup",
                   homeMeal: "wholegrain toast with eggs and tomatoes", protein: "white beans or fish", fruit: "plum or kiwi")]
        case .subSaharanAfrica:
            [Foods(produce: "tomato or carrot", warmDish: "a lentil and pumpkin stew",
                   homeMeal: "rice with lentils and greens", protein: "chickpeas or eggs", fruit: "orange or papaya"),
             Foods(produce: "cabbage or cucumber", warmDish: "a bean and greens soup",
                   homeMeal: "millet with beans and vegetables", protein: "beans or chicken", fruit: "guava or pineapple"),
             Foods(produce: "lettuce or radish", warmDish: "a vegetable and chickpea stew",
                   homeMeal: "sweet potato with eggs and greens", protein: "lentils or tofu", fruit: "apple or melon")]
        case .northAmerica:
            [Foods(produce: "tomato or carrot", warmDish: "a lentil and vegetable stew",
                   homeMeal: "a bean and vegetable wrap", protein: "lentils or tofu", fruit: "orange or pear"),
             Foods(produce: "cabbage or lettuce", warmDish: "a squash and chickpea soup",
                   homeMeal: "rice with broccoli and tofu", protein: "chickpeas or fish", fruit: "banana or grapes"),
             Foods(produce: "radish or cucumber", warmDish: "a barley and mushroom soup",
                   homeMeal: "a baked sweet potato with beans and greens", protein: "eggs or edamame", fruit: "peach or kiwi")]
        case .latinAmerica:
            [Foods(produce: "tomato or carrot", warmDish: "a lentil and vegetable stew",
                   homeMeal: "corn tortillas with eggs and greens", protein: "lentils or chicken", fruit: "orange or mango"),
             Foods(produce: "cabbage or radish", warmDish: "a squash and chickpea soup",
                   homeMeal: "rice with lentils and carrots", protein: "chickpeas or tofu", fruit: "guava or pineapple"),
             Foods(produce: "lettuce or cucumber", warmDish: "a corn and vegetable soup",
                   homeMeal: "sweet potato with beans and salad", protein: "black beans or eggs", fruit: "apple or melon")]
        case .oceania:
            [Foods(produce: "tomato or carrot", warmDish: "a lentil and pumpkin soup",
                   homeMeal: "rice with tofu and greens", protein: "lentils or chicken", fruit: "pear or berries"),
             Foods(produce: "cabbage or radish", warmDish: "a bean and barley stew",
                   homeMeal: "a chickpea and vegetable wrap", protein: "chickpeas or eggs", fruit: "banana or kiwi"),
             Foods(produce: "lettuce or cucumber", warmDish: "a mushroom and vegetable soup",
                   homeMeal: "sweet potato with beans and spinach", protein: "tofu or fish", fruit: "peach or grapes")]
        case .general:
            [Foods(produce: "tomato or carrot", warmDish: "a lentil and vegetable stew",
                   homeMeal: "rice with beans and greens", protein: "chickpeas or tofu", fruit: "apple or orange"),
             Foods(produce: "cabbage or radish", warmDish: "a pumpkin and chickpea soup",
                   homeMeal: "wholegrain bread with eggs and tomatoes", protein: "lentils or fish", fruit: "banana or pear"),
             Foods(produce: "lettuce or cucumber", warmDish: "a barley and mushroom soup",
                   homeMeal: "potatoes with lentils and spinach", protein: "beans or eggs", fruit: "melon or grapes")]
        }
        return [foods] + alternatives
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
