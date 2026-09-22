import Foundation
import HealthKit

/// Reads last night's sleep from HealthKit. Read-only — Roastie never writes
/// to Health. Only usable from the main app target (HealthKit isn't
/// available to the widget/notification-service extensions).
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable, let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        try await store.requestAuthorization(toShare: [], read: [sleepType])
    }

    /// Total asleep time (core/deep/REM/unspecified) in the 24h window ending
    /// at noon on `referenceDate`, i.e. "last night's sleep" as of any check-in today.
    func sleepHoursLastNight(referenceDate: Date = .now) async throws -> Double? {
        guard isAvailable, let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let calendar = Calendar.current
        let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: referenceDate) ?? referenceDate
        let start = calendar.date(byAdding: .hour, value: -24, to: end) ?? end.addingTimeInterval(-24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let seconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: seconds > 0 ? seconds / 3600.0 : nil)
            }
            store.execute(query)
        }
    }
}
