import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

let snapshot = AICoachSnapshot(
    weeklyTarget: 14_000,
    loggedThisWeek: 6_250,
    remainingDays: 4,
    remainingDailyAverage: 1_937.5,
    caloriesRemainingToday: 820,
    proteinRemainingToday: 63,
    yesterdayCalories: 1_940,
    yesterdayProtein: 132,
    yesterdayDeficit: 480,
    reviewedPastDays: 2,
    unreviewedPastDays: 1,
    availableFoodOptions: 3,
    weeklyWeightLossGoal: 1
)
let prompt = AICoachPrompt.userMessage(for: snapshot)
expect(prompt.contains("Weekly calorie target: 14000 kcal"), "weekly target")
expect(prompt.contains("Today remaining: 820 kcal and 63 g protein"), "today target")
expect(prompt.contains("Past days awaiting review: 1"), "review uncertainty")
expect(!prompt.localizedCaseInsensitiveContains("barcode"), "no barcode field")
expect(!prompt.localizedCaseInsensitiveContains("healthkit"), "no raw Health reference")
expect(!prompt.contains("2026-"), "no date")

let missing = AICoachSnapshot(
    weeklyTarget: 14_000, loggedThisWeek: 0, remainingDays: 7, remainingDailyAverage: nil,
    caloriesRemainingToday: 2_000, proteinRemainingToday: 140, yesterdayCalories: nil,
    yesterdayProtein: nil, yesterdayDeficit: nil, reviewedPastDays: 0, unreviewedPastDays: 0,
    availableFoodOptions: 0, weeklyWeightLossGoal: 1
)
let missingPrompt = AICoachPrompt.userMessage(for: missing)
expect(missingPrompt.components(separatedBy: "unavailable").count == 4, "missing values remain unavailable")
print("AI coach prompt scenarios passed")

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

var postedBody: [String: Any]?
func requestBody(_ request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        guard count > 0 else { break }
        result.append(contentsOf: buffer.prefix(count))
    }
    return result
}
MockURLProtocol.handler = { request in
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    if request.url?.path == "/api/v1/models" {
        let data = Data("""
        {"data":[
          {"id":"paid/model","pricing":{"prompt":"0.1","completion":"0.1"},"architecture":{"input_modalities":["text"]}},
          {"id":"best/free:model","pricing":{"prompt":"0","completion":"0"},"architecture":{"input_modalities":["text"]}},
          {"id":"image/free:model","pricing":{"prompt":"0","completion":"0"},"architecture":{"input_modalities":["image"]}}
        ]}
        """.utf8)
        return (response, data)
    }
    postedBody = try JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any]
    return (response, Data("{\"model\":\"best/free:model\",\"choices\":[{\"message\":{\"content\":\"Useful advice\"}}]}".utf8))
}
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [MockURLProtocol.self]
let client = OpenRouterClient(session: URLSession(configuration: configuration))
let result = try await client.insight(for: snapshot, apiKey: String(repeating: "k", count: 24))
expect(result.model == "best/free:model", "response model is retained")
expect(postedBody?["model"] as? String == "best/free:model", "highest-ranked free text model is selected")
let provider = postedBody?["provider"] as? [String: Any]
expect(provider?["data_collection"] as? String == "deny", "provider data collection is denied")
let messages = postedBody?["messages"] as? [[String: Any]]
expect(messages?.count == 2, "bounded two-message request")
let bodyText = String(data: try JSONSerialization.data(withJSONObject: postedBody!), encoding: .utf8) ?? ""
expect(!bodyText.contains(String(repeating: "k", count: 24)), "API key never enters body")
print("AI coach request scenarios passed")
