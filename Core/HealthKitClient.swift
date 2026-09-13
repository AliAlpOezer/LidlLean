import HealthKit

struct ActivitySnapshot: Equatable {
    let activeEnergy: Double?
    let basalEnergy: Double?
    let steps: Double?
    let walkingDistance: Double?
    let exerciseMinutes: Double?
    let weight: Double?
    let bodyFatPercent: Double?
    static let unavailable = ActivitySnapshot(activeEnergy: nil, basalEnergy: nil, steps: nil, walkingDistance: nil, exerciseMinutes: nil, weight: nil, bodyFatPercent: nil)
}

actor HealthKitClient {
    private let store = HKHealthStore()
    func requestAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: [
            HKQuantityType(.activeEnergyBurned), HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.appleExerciseTime), HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage)
        ])
    }
    func todaySnapshot() async -> ActivitySnapshot {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        async let energy = sum(.activeEnergyBurned, .kilocalorie())
        async let basal = sum(.basalEnergyBurned, .kilocalorie())
        async let steps = sum(.stepCount, .count())
        async let distance = sum(.distanceWalkingRunning, .meterUnit(with: .kilo))
        async let exercise = sum(.appleExerciseTime, .minute())
        async let weight = latest(.bodyMass, .gramUnit(with: .kilo))
        async let bodyFat = latest(.bodyFatPercentage, .percent())
        return await ActivitySnapshot(activeEnergy: energy, basalEnergy: basal, steps: steps, walkingDistance: distance, exerciseMinutes: exercise, weight: weight, bodyFatPercent: bodyFat.map { $0 * 100 })
    }
    private func sum(_ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit) async -> Double? {
        let start = Calendar.current.startOfDay(for: .now)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: HKQuantityType(identifier), quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: .now), options: .cumulativeSum) { _, result, _ in continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit)) }
            store.execute(query)
        }
    }
    private func latest(_ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKQuantityType(identifier), predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, _ in
                continuation.resume(returning: (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}
