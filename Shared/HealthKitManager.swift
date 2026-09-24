import Foundation
import HealthKit

extension Notification.Name {
    static let healthStepCountDidChange = Notification.Name("healthStepCountDidChange")
}

/// Reads sleep and the current day's step total from HealthKit. Read-only —
/// Roastie never writes to Health. Step totals remain ephemeral and are not
/// copied into the app's database, shared snapshot, or backup.
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()
    private var stepObserverQuery: HKObserverQuery?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable, let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        try await store.requestAuthorization(toShare: [], read: [sleepType])
    }

    func requestStepAuthorization() async throws {
        guard isAvailable,
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        else { return }
        try await store.requestAuthorization(toShare: [], read: [stepType])
        try await enableStepBackgroundDelivery(for: stepType)
    }

    /// Returns today's cumulative Health step count. `nil` means Health has
    /// no readable sample; zero is returned only when Health reports zero.
    func stepsToday(referenceDate: Date = .now) async throws -> Int? {
        guard isAvailable,
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        else { return nil }

        let start = Calendar.current.startOfDay(for: referenceDate)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: referenceDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let count = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: count.map { max(0, Int($0.rounded())) })
            }
            store.execute(query)
        }
    }

    /// HealthKit observer delivery is opportunistic, so this keeps the UI and
    /// the already-scheduled 10 p.m. summary fresher without promising a live
    /// pedometer. The callback always completes the observer transaction.
    func startObservingSteps(onUpdate: @escaping @MainActor @Sendable () async -> Void) {
        guard stepObserverQuery == nil,
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        else { return }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completion, error in
            if let error {
                AppLogger.report(error, operation: "Observe Health steps", logger: AppLogger.health)
                completion()
                return
            }
            Task { @MainActor in
                await onUpdate()
            }
            // The observer transaction is complete once the refresh has been
            // handed to the main actor; the query itself happens separately.
            completion()
        }
        stepObserverQuery = query
        store.execute(query)

        Task {
            do {
                try await enableStepBackgroundDelivery(for: stepType)
            } catch {
                AppLogger.report(error, operation: "Enable step background delivery", logger: AppLogger.health)
            }
        }
    }

    private func enableStepBackgroundDelivery(for stepType: HKQuantityType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.backgroundDeliveryUnavailable)
                }
            }
        }
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

private enum HealthKitError: LocalizedError {
    case backgroundDeliveryUnavailable

    var errorDescription: String? {
        "Health did not enable background step updates."
    }
}
