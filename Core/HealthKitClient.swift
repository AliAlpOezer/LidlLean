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

    nonisolated static func userFacingError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("com.apple.developer.healthkit") || message.contains("missing entitlement") {
            return "This build was signed without the HealthKit capability. Add HealthKit to your App ID, regenerate the provisioning profile, and reinstall the signed build."
        }
        if let healthError = error as? HKError, healthError.code == .errorAuthorizationDenied {
            return "Apple Health access was denied. Open Settings > Health > Data Access & Devices > LidlLean and enable the categories you want to share."
        }
        return error.localizedDescription
    }
    func energyHistory(from start: Date, to end: Date, calendar: Calendar) async throws -> [Date: (resting: Double?, active: Double?)] {
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }
        async let resting = dailyEnergy(.basalEnergyBurned, from: start, to: end, calendar: calendar)
        async let active = dailyEnergy(.activeEnergyBurned, from: start, to: end, calendar: calendar)
        let (restingValues, activeValues) = try await (resting, active)
        var result: [Date: (resting: Double?, active: Double?)] = [:]
        var day = calendar.startOfDay(for: start)
        while day < end {
            result[day] = (restingValues[day], activeValues[day])
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    func weightHistory(from start: Date, to end: Date, calendar: Calendar) async throws -> [Date: Double] {
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }
        return try await dailyEnergy(.bodyMass, from: start, to: end, calendar: calendar,
                                     unit: .gramUnit(with: .kilo), options: .discreteAverage)
    }

    private func dailyEnergy(_ identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date,
                             calendar: Calendar, unit: HKUnit = .kilocalorie(),
                             options: HKStatisticsOptions = .cumulativeSum) async throws -> [Date: Double] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(identifier),
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                options: options, anchorDate: calendar.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1))
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                var values: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let quantity = options == .discreteAverage ? statistics.averageQuantity() : statistics.sumQuantity()
                    if let quantity {
                        values[calendar.startOfDay(for: statistics.startDate)] = quantity.doubleValue(for: unit)
                    }
                }
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }
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
