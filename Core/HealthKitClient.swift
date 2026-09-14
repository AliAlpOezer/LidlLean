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
    private let imported = HealthImportStore.shared

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
        let importedValues = await imported.energyHistory(from: start, to: end)
        guard HKHealthStore.isHealthDataAvailable() else { return importedValues }
        do {
            async let resting = dailyEnergy(.basalEnergyBurned, from: start, to: end, calendar: calendar)
            async let active = dailyEnergy(.activeEnergyBurned, from: start, to: end, calendar: calendar)
            let (restingValues, activeValues) = try await (resting, active)
            var result: [Date: (resting: Double?, active: Double?)] = [:]
            var day = calendar.startOfDay(for: start)
            while day < end {
                let importedDay = importedValues[day]
                result[day] = (restingValues[day] ?? importedDay?.resting,
                               activeValues[day] ?? importedDay?.active)
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
            return result
        } catch {
            if importedValues.values.contains(where: { $0.resting != nil || $0.active != nil }) { return importedValues }
            throw error
        }
    }

    func weightHistory(from start: Date, to end: Date, calendar: Calendar) async throws -> [Date: Double] {
        let importedValues = await imported.weightHistory(from: start, to: end)
        guard HKHealthStore.isHealthDataAvailable() else { return importedValues }
        do {
            let live = try await dailyEnergy(.bodyMass, from: start, to: end, calendar: calendar,
                                             unit: .gramUnit(with: .kilo), options: .discreteAverage)
            return importedValues.merging(live) { _, liveValue in liveValue }
        } catch {
            if !importedValues.isEmpty { return importedValues }
            throw error
        }
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
        let importedSnapshot = await imported.todaySnapshot()
        guard HKHealthStore.isHealthDataAvailable() else { return importedSnapshot }
        async let energy = sum(.activeEnergyBurned, .kilocalorie())
        async let basal = sum(.basalEnergyBurned, .kilocalorie())
        async let steps = sum(.stepCount, .count())
        async let distance = sum(.distanceWalkingRunning, .meterUnit(with: .kilo))
        async let exercise = sum(.appleExerciseTime, .minute())
        async let weight = latest(.bodyMass, .gramUnit(with: .kilo))
        async let bodyFat = latest(.bodyFatPercentage, .percent())
        return await ActivitySnapshot(activeEnergy: energy ?? importedSnapshot.activeEnergy,
                                      basalEnergy: basal ?? importedSnapshot.basalEnergy,
                                      steps: steps ?? importedSnapshot.steps,
                                      walkingDistance: distance ?? importedSnapshot.walkingDistance,
                                      exerciseMinutes: exercise ?? importedSnapshot.exerciseMinutes,
                                      weight: weight ?? importedSnapshot.weight,
                                      bodyFatPercent: bodyFat.map { $0 * 100 } ?? importedSnapshot.bodyFatPercent)
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
