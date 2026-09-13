import HealthKit

struct ActivitySnapshot: Equatable { let activeEnergy: Double?; let steps: Double?; static let unavailable = ActivitySnapshot(activeEnergy: nil, steps: nil) }

actor HealthKitClient {
    private let store = HKHealthStore()
    func requestAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: [HKQuantityType(.activeEnergyBurned), HKQuantityType(.stepCount)])
    }
    func todaySnapshot() async -> ActivitySnapshot {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        async let energy = sum(.activeEnergyBurned, .kilocalorie())
        async let steps = sum(.stepCount, .count())
        return await ActivitySnapshot(activeEnergy: energy, steps: steps)
    }
    private func sum(_ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit) async -> Double? {
        let start = Calendar.current.startOfDay(for: .now)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: HKQuantityType(identifier), quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: .now), options: .cumulativeSum) { _, result, _ in continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit)) }
            store.execute(query)
        }
    }
}
