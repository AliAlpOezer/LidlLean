import Foundation

struct LidlFlyer: Identifiable, Equatable {
    let title: String
    let validity: String
    var id: String { "\(title)-\(validity)" }
}

actor LidlFlyerClient {
    static let officialProspectURL = URL(string: "https://www.lidl.de/c/online-prospekte/s10005610/")!

    func currentFlyers() async throws -> [LidlFlyer] {
        var request = URLRequest(url: Self.officialProspectURL)
        request.setValue("LidlLean/1.0 personal shopping planner", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let html = String(decoding: data, as: UTF8.self)
        let expression = try NSRegularExpression(pattern: "Aktionsprospekt\\s*([0-9]{2}\\.[0-9]{2}\\.[0-9]{4}\\s*[–-]\\s*[0-9]{2}\\.[0-9]{2}\\.[0-9]{4})", options: [.caseInsensitive])
        let range = NSRange(html.startIndex..., in: html)
        let dates = expression.matches(in: html, range: range).compactMap { match -> String? in
            guard let dateRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[dateRange])
        }
        return Array(Set(dates)).sorted().map { LidlFlyer(title: "Aktionsprospekt", validity: $0) }
    }
}
