import Foundation

struct ImportedHealthDay: Codable, Equatable, Sendable {
    var activeKcal: Double?
    var restingKcal: Double?
    var steps: Double?
    var walkingDistanceKm: Double?
    var exerciseMinutes: Double?
    var weightKg: Double?
    var bodyFatPercent: Double?

    static let empty = ImportedHealthDay(activeKcal: nil, restingKcal: nil, steps: nil,
                                         walkingDistanceKm: nil, exerciseMinutes: nil,
                                         weightKg: nil, bodyFatPercent: nil)
}

struct HealthImportSummary: Sendable {
    let days: Int
    let records: Int
    let importedAt: Date
}

actor HealthImportStore {
    static let shared = HealthImportStore()

    private struct StoredData: Codable {
        var days: [String: ImportedHealthDay] = [:]
        var importedAt: Date?
    }

    private var data: StoredData
    private let calendar = Calendar.autoupdatingCurrent
    private let dayFormatter: DateFormatter

    init() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        dayFormatter = formatter
        data = Self.loadStoredData()
    }

    func todaySnapshot() -> ActivitySnapshot {
        let key = dayKey(for: .now)
        let day = data.days[key] ?? .empty
        return ActivitySnapshot(activeEnergy: day.activeKcal, basalEnergy: day.restingKcal,
                                steps: day.steps, walkingDistance: day.walkingDistanceKm,
                                exerciseMinutes: day.exerciseMinutes, weight: day.weightKg,
                                bodyFatPercent: day.bodyFatPercent)
    }

    func energyHistory(from start: Date, to end: Date) -> [Date: (resting: Double?, active: Double?)] {
        var result: [Date: (resting: Double?, active: Double?)] = [:]
        var day = calendar.startOfDay(for: start)
        while day < end {
            let stored = data.days[dayKey(for: day)]
            result[day] = (stored?.restingKcal, stored?.activeKcal)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    func weightHistory(from start: Date, to end: Date) -> [Date: Double] {
        var result: [Date: Double] = [:]
        var day = calendar.startOfDay(for: start)
        while day < end {
            if let value = data.days[dayKey(for: day)]?.weightKg { result[day] = value }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    func importShortcut(url: URL) throws -> HealthImportSummary {
        guard url.scheme?.lowercased() == "lidllean", url.host?.lowercased() == "health-sync" else {
            throw HealthImportError.invalidURL
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var query: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            if let value = item.value { query[item.name] = value }
        }
        guard let date = query["date"], isDay(date) else { throw HealthImportError.invalidDate }

        var day = data.days[date] ?? .empty
        day.activeKcal = try optionalValue(query["activeKcal"], maximum: 20_000)
        day.restingKcal = try optionalValue(query["restingKcal"], maximum: 20_000)
        day.steps = try optionalValue(query["steps"], maximum: 2_000_000)
        day.walkingDistanceKm = try optionalValue(query["walkingKm"], maximum: 2_000)
        day.exerciseMinutes = try optionalValue(query["exerciseMin"], maximum: 2_000)
        day.weightKg = try optionalValue(query["weightKg"], maximum: 500)
        day.bodyFatPercent = try optionalValue(query["bodyFatPercent"], maximum: 100)
        guard day != .empty else { throw HealthImportError.noMetrics }
        data.days[date] = day
        data.importedAt = .now
        try persist()
        return HealthImportSummary(days: 1, records: query.count - 1, importedAt: data.importedAt!)
    }

    func importXML(from url: URL) throws -> HealthImportSummary {
        let parser = HealthXMLParser()
        guard let stream = InputStream(url: url) else { throw HealthImportError.fileUnreadable }
        stream.open()
        defer { stream.close() }
        guard parser.parse(stream), parser.error == nil else {
            throw HealthImportError.invalidXML(parser.error?.localizedDescription ?? "The XML could not be read.")
        }

        var activities: [String: ImportedHealthDay] = [:]
        var weights: [String: [Double]] = [:]
        var bodyFat: [String: [Double]] = [:]
        var seen = Set<String>()
        for record in parser.records {
            guard Self.supportedTypes.contains(record.type) else { continue }
            let identity = "\(record.type)|\(record.startDate.timeIntervalSince1970)|\(record.endDate.timeIntervalSince1970)|\(record.value)|\(record.unit)|\(record.source)"
            guard seen.insert(identity).inserted else { continue }
            let key = dayKey(for: record.startDate)
            guard var day = activities[key] else {
                activities[key] = try apply(record, to: .empty, weights: &weights, bodyFat: &bodyFat, key: key)
                continue
            }
            day = try apply(record, to: day, weights: &weights, bodyFat: &bodyFat, key: key)
            activities[key] = day
        }
        for (key, values) in weights where !values.isEmpty {
            activities[key, default: .empty].weightKg = values.reduce(0, +) / Double(values.count)
        }
        for (key, values) in bodyFat where !values.isEmpty {
            activities[key, default: .empty].bodyFatPercent = values.reduce(0, +) / Double(values.count)
        }
        guard !activities.isEmpty else { throw HealthImportError.noRecognizedRecords }
        data.days.merge(activities) { existing, imported in
            ImportedHealthDay(activeKcal: imported.activeKcal ?? existing.activeKcal,
                              restingKcal: imported.restingKcal ?? existing.restingKcal,
                              steps: imported.steps ?? existing.steps,
                              walkingDistanceKm: imported.walkingDistanceKm ?? existing.walkingDistanceKm,
                              exerciseMinutes: imported.exerciseMinutes ?? existing.exerciseMinutes,
                              weightKg: imported.weightKg ?? existing.weightKg,
                              bodyFatPercent: imported.bodyFatPercent ?? existing.bodyFatPercent)
        }
        data.importedAt = .now
        try persist()
        return HealthImportSummary(days: activities.count, records: parser.records.count, importedAt: data.importedAt!)
    }

    private func apply(_ record: HealthXMLParser.Record, to day: ImportedHealthDay,
                       weights: inout [String: [Double]], bodyFat: inout [String: [Double]], key: String) throws -> ImportedHealthDay {
        var result = day
        switch record.type {
        case "HKQuantityTypeIdentifierActiveEnergyBurned":
            result.activeKcal = (result.activeKcal ?? 0) + try convert(record.value, unit: record.unit, kind: .kcal)
        case "HKQuantityTypeIdentifierBasalEnergyBurned":
            result.restingKcal = (result.restingKcal ?? 0) + try convert(record.value, unit: record.unit, kind: .kcal)
        case "HKQuantityTypeIdentifierStepCount":
            result.steps = (result.steps ?? 0) + try convert(record.value, unit: record.unit, kind: .steps)
        case "HKQuantityTypeIdentifierDistanceWalkingRunning":
            result.walkingDistanceKm = (result.walkingDistanceKm ?? 0) + try convert(record.value, unit: record.unit, kind: .kilometers)
        case "HKQuantityTypeIdentifierAppleExerciseTime":
            result.exerciseMinutes = (result.exerciseMinutes ?? 0) + try convert(record.value, unit: record.unit, kind: .minutes)
        case "HKQuantityTypeIdentifierBodyMass":
            weights[key, default: []].append(try convert(record.value, unit: record.unit, kind: .kilograms))
        case "HKQuantityTypeIdentifierBodyFatPercentage":
            bodyFat[key, default: []].append(try convert(record.value, unit: record.unit, kind: .percent))
        default:
            break
        }
        return result
    }

    private enum UnitKind { case kcal, steps, kilometers, minutes, kilograms, percent }

    private static let supportedTypes: Set<String> = [
        "HKQuantityTypeIdentifierActiveEnergyBurned",
        "HKQuantityTypeIdentifierBasalEnergyBurned",
        "HKQuantityTypeIdentifierStepCount",
        "HKQuantityTypeIdentifierDistanceWalkingRunning",
        "HKQuantityTypeIdentifierAppleExerciseTime",
        "HKQuantityTypeIdentifierBodyMass",
        "HKQuantityTypeIdentifierBodyFatPercentage"
    ]

    private func convert(_ value: Double, unit: String, kind: UnitKind) throws -> Double {
        guard value.isFinite, value >= 0 else { throw HealthImportError.invalidValue }
        let normalized = unit.lowercased().replacingOccurrences(of: " ", with: "")
        switch kind {
        case .kcal: return normalized.contains("kj") ? value / 4.184 : value
        case .steps: return value
        case .kilometers:
            if normalized.contains("mi") { return value * 1.609344 }
            if normalized == "m" || normalized.contains("meter") { return value / 1_000 }
            return value
        case .minutes:
            if normalized.contains("sec") || normalized == "s" { return value / 60 }
            if normalized.contains("hour") || normalized == "h" { return value * 60 }
            return value
        case .kilograms:
            if normalized == "g" || normalized.contains("gram") { return value / 1_000 }
            if normalized.contains("lb") { return value * 0.45359237 }
            return value
        case .percent: return normalized == "%" && value <= 1 ? value * 100 : value
        }
    }

    private func optionalValue(_ raw: String?, maximum: Double) throws -> Double? {
        guard let raw, !raw.isEmpty else { return nil }
        guard let value = Double(raw), value.isFinite, value >= 0, value <= maximum else { throw HealthImportError.invalidValue }
        return value
    }

    private func isDay(_ value: String) -> Bool {
        dayFormatter.date(from: value) != nil && value.count == 10
    }

    private func dayKey(for date: Date) -> String { dayFormatter.string(from: calendar.startOfDay(for: date)) }

    private func persist() throws {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("HealthImport.json")
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: url, options: .atomic)
    }

    private static func loadStoredData() -> StoredData {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("HealthImport.json")
        guard let stored = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(StoredData.self, from: stored) else { return StoredData() }
        return decoded
    }
}

enum HealthImportError: LocalizedError {
    case invalidURL, invalidDate, noMetrics, fileUnreadable, invalidValue, noRecognizedRecords
    case invalidXML(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "This link is not a LidlLean health-sync link."
        case .invalidDate: return "The health sync did not contain a valid date."
        case .noMetrics: return "The health sync did not contain any recognized metrics."
        case .fileUnreadable: return "The selected Health XML file could not be opened."
        case .invalidValue: return "The Health export contained an invalid or unsafe value."
        case .noRecognizedRecords: return "No supported activity or body records were found in this Health export."
        case .invalidXML(let message): return "The Health XML could not be read: \(message)"
        }
    }
}

final class HealthXMLParser: NSObject, XMLParserDelegate {
    struct Record {
        let type: String
        let value: Double
        let unit: String
        let startDate: Date
        let endDate: Date
        let source: String
    }

    private(set) var records: [Record] = []
    private(set) var error: Error?
    private let dateFormatters: [DateFormatter] = {
        let formats = ["yyyy-MM-dd HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssXXXXX"]
        return formats.map {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = $0
            return formatter
        }
    }()

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) { error = parseError }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        guard elementName == "Record",
              let type = attributeDict["type"],
              let value = Double(attributeDict["value"] ?? ""),
              let start = parseDate(attributeDict["startDate"] ?? ""),
              let end = parseDate(attributeDict["endDate"] ?? "") else { return }
        records.append(Record(type: type, value: value, unit: attributeDict["unit"] ?? "",
                              startDate: start, endDate: end, source: attributeDict["sourceName"] ?? ""))
    }

    private func parseDate(_ value: String) -> Date? { dateFormatters.lazy.compactMap { $0.date(from: value) }.first }
}
