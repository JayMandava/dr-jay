import Foundation
import SwiftData

/// Deliberately absent from navigation and suggestions. Whole submitted commands only.
enum HiddenLogCommand {
    static func match(_ text: String) -> ExposureKind? {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "spirits": .alcohol
        case "smoke": .smoke
        default: nil
        }
    }
}

enum ExposureKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case alcohol, smoke
    var id: Self { self }
    var label: String { self == .alcohol ? "Spirits" : "Smoke" }
    var symbol: String { self == .alcohol ? "wineglass" : "smoke" }
    var unit: String { self == .alcohol ? "UK alcohol units" : "cigarettes" }
    func unit(for quantity: Double) -> String {
        guard quantity == 1 else { return unit }
        return self == .alcohol ? "UK alcohol unit" : "cigarette"
    }
}

struct ExposureEntry: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var kind: ExposureKind
    var quantity: Double
    var timestamp: Date
    var note: String? = nil
}

/// Product accountability policy, not a clinical risk estimate or safe-use allowance.
/// Alcohol: 8 points per UK unit (10ml pure alcohol), plus 12 per unit above two per day.
/// Smoke: 20 points per cigarette from the first.
/// Combined deduction saturates at 100. Clamp before arithmetic to prevent overflow.
struct ExposureSummary: Equatable, Sendable {
    let alcoholUnits: Double
    let cigarettes: Int
    private let scoredAlcohol: Decimal

    init(alcoholUnits: Double = 0, cigarettes: Int = 0) {
        self.alcoholUnits = alcoholUnits.isFinite ? max(0, alcoholUnits) : 0
        self.cigarettes = max(0, cigarettes)
        self.scoredAlcohol = Self.decimal(min(self.alcoholUnits, 100))
    }

    init(entries: [ExposureEntry]) {
        // Decimal addition preserves the entered decimal quantities independently of order.
        // Counts above this generous display ceiling are already far beyond score saturation.
        let displayCeiling = Decimal(1_000_000_000_000_000_000 as Int64)
        var alcohol = Decimal.zero
        var hugeAlcohol = false
        var smoke = 0
        for entry in entries where entry.quantity.isFinite && entry.quantity > 0 {
            if entry.kind == .alcohol {
                if entry.quantity > 1e18 { hugeAlcohol = true }
                alcohol = min(displayCeiling, alcohol + Self.decimal(min(entry.quantity, 1e18)))
            } else if entry.quantity.rounded(.down) == entry.quantity {
                let count = entry.quantity >= Double(Int.max) ? Int.max : Int(entry.quantity)
                let (sum, overflow) = smoke.addingReportingOverflow(count)
                smoke = overflow ? Int.max : sum
            }
        }
        self.alcoholUnits = hugeAlcohol ? Double.greatestFiniteMagnitude : NSDecimalNumber(decimal: alcohol).doubleValue
        self.cigarettes = smoke
        self.scoredAlcohol = min(100, alcohol)
    }

    private static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    var isEmpty: Bool { alcoholUnits == 0 && cigarettes == 0 }
    var exceedsAlcoholThreshold: Bool { alcoholUnits > 2 }
    var penalty: Int {
        let alcohol = min(100, scoredAlcohol * 8 + max(0, scoredAlcohol - 2) * 12)
        var raw = alcohol
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &raw, 0, .plain)
        let smoke = min(100, min(cigarettes, 5) * 20)
        return min(100, NSDecimalNumber(decimal: rounded).intValue + smoke)
    }

    var detail: String {
        "Alcohol \(alcoholUnits.formatted(.number.precision(.fractionLength(0...3)))) UK \(alcoholUnits == 1 ? "unit" : "units") · Smoke \(cigarettes) \(cigarettes == 1 ? "cigarette" : "cigarettes") · Score −\(penalty)"
    }

    /// Always the strongest local feedback; never changes the user's other roast settings.
    var roast: String {
        if cigarettes > 0 && exceedsAlcoholThreshold {
            return "The bar tab and the ashtray have formed a coalition against your score. Past two alcohol units, the deduction accelerates; every cigarette counts from the first."
        }
        if cigarettes > 0 {
            return "Your lungs did not order the smoke tasting menu. Even the first cigarette costs points; a good workout does not cancel that invoice."
        }
        if exceedsAlcoholThreshold {
            return "The third alcohol unit has promoted this bar tab to a disciplinary hearing. The score deduction now accelerates. Water is not a refund desk."
        }
        return "The liver has received your liquid expense claim and rejected it. Every alcohol unit costs points; the second is not a free pass."
    }
}

/// The same transactional persistence path is used by the hidden sheet and tests.
@MainActor
enum ExposureLogStore {
    static func save(
        _ entry: ExposureEntry, dayKey: String, context: ModelContext,
        waterGoal: Int, now: Date = .now
    ) throws -> DailyLog {
        guard entry.quantity.isFinite,
              entry.kind == .alcohol ? (0.5...1000).contains(entry.quantity)
                  : ((1...1000).contains(entry.quantity) && entry.quantity.rounded(.down) == entry.quantity),
              entry.timestamp <= now,
              entry.timestamp.dayKey == dayKey, (entry.note?.count ?? 0) <= 500 else { throw ValidationError.invalidEntry }
        let existing = try context.fetch(FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dayKey == dayKey })).first
        let log = existing ?? DailyLog(dayKey: dayKey, date: entry.timestamp.startOfDay, waterGoalBottles: waterGoal)
        if existing == nil { context.insert(log) }
        let previous = log.exposureEntries
        var entries = previous ?? []
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        log.exposureEntries = entries
        do { try context.save() } catch {
            log.exposureEntries = previous
            if existing == nil { context.delete(log) }
            throw error
        }
        return log
    }

    static func delete(id: UUID, dayKey: String, context: ModelContext) throws -> DailyLog? {
        guard let log = try context.fetch(FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dayKey == dayKey })).first else { return nil }
        let previous = log.exposureEntries
        log.exposureEntries = (previous ?? []).filter { $0.id != id }
        do { try context.save() } catch {
            log.exposureEntries = previous
            throw error
        }
        return log
    }

    enum ValidationError: Error { case invalidEntry }
}
