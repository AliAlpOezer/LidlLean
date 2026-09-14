import Foundation

struct AICoachSnapshot: Equatable {
    let weeklyTarget: Double
    let loggedThisWeek: Double
    let remainingDays: Int
    let remainingDailyAverage: Double?
    let caloriesRemainingToday: Double
    let proteinRemainingToday: Double
    let yesterdayCalories: Double?
    let yesterdayProtein: Double?
    let yesterdayDeficit: Double?
    let reviewedPastDays: Int
    let unreviewedPastDays: Int
    let availableFoodOptions: Int
    let weeklyWeightLossGoal: Double
}

enum AICoachPrompt {
    static let system = """
    You are a careful nutrition planning assistant. Interpret the supplied aggregate numbers without changing targets or inventing missing data. Give exactly three short bullets: what the numbers show, one practical action for today that protects protein, and one shopping or preparation suggestion. Do not diagnose, promise weight loss, prescribe supplements, or recommend eating below the supplied target. Explicitly label uncertainty when records are incomplete.
    """

    static func userMessage(for snapshot: AICoachSnapshot) -> String {
        let remainingAverage = snapshot.remainingDailyAverage.map { "\(Int($0)) kcal" } ?? "unavailable"
        let yesterday = snapshot.yesterdayCalories.map { "\(Int($0)) kcal, \(Int(snapshot.yesterdayProtein ?? 0)) g protein" } ?? "unavailable"
        let deficit = snapshot.yesterdayDeficit.map { "\(Int($0)) kcal" } ?? "unavailable"
        return """
        Weekly calorie target: \(Int(snapshot.weeklyTarget)) kcal
        Calories logged this week: \(Int(snapshot.loggedThisWeek)) kcal
        Days remaining including today: \(snapshot.remainingDays)
        Remaining daily average: \(remainingAverage)
        Today remaining: \(Int(snapshot.caloriesRemainingToday)) kcal and \(Int(snapshot.proteinRemainingToday)) g protein
        Yesterday reviewed intake: \(yesterday)
        Yesterday estimated deficit: \(deficit)
        Past days reviewed: \(snapshot.reviewedPastDays)
        Past days awaiting review: \(snapshot.unreviewedPastDays)
        Confirmed food options currently available: \(snapshot.availableFoodOptions)
        User-selected weekly weight-loss goal: \(snapshot.weeklyWeightLossGoal.formatted(.number.precision(.fractionLength(1)))) kg
        """
    }
}

struct AICoachResponse: Equatable {
    let text: String
    let model: String
}

enum AICoachError: LocalizedError {
    case invalidKey
    case invalidResponse
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidKey: "Enter a valid OpenRouter API key."
        case .invalidResponse: "OpenRouter returned a response the app could not read."
        case let .server(status, message):
            if status == 401 { "OpenRouter rejected the API key." }
            else if status == 429 { "The free-model rate limit has been reached. Try again later." }
            else { "OpenRouter error \(status): \(message)" }
        }
    }
}

struct OpenRouterClient {
    private let session: URLSession
    private let chatURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private let modelsURL = URL(string: "https://openrouter.ai/api/v1/models")!
    private let fallbackModel = "openrouter/free"

    init(session: URLSession? = nil) {
        if let session { self.session = session }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 45
            configuration.timeoutIntervalForResource = 60
            configuration.httpMaximumConnectionsPerHost = 1
            self.session = URLSession(configuration: configuration)
        }
    }

    func insight(for snapshot: AICoachSnapshot, apiKey: String) async throws -> AICoachResponse {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 20 else { throw AICoachError.invalidKey }
        let selectedModel = await bestFreeModel(apiKey: key)
        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("LidlLean", forHTTPHeaderField: "X-OpenRouter-Title")
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: selectedModel,
            messages: [
                .init(role: "system", content: AICoachPrompt.system),
                .init(role: "user", content: AICoachPrompt.userMessage(for: snapshot))
            ],
            maxTokens: 360,
            temperature: 0.2,
            provider: .init(dataCollection: "deny")
        ))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AICoachError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error.message) ?? "Request failed"
            throw AICoachError.server(status: http.statusCode, message: message)
        }
        guard let result = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let text = result.choices.first?.message.content.text.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw AICoachError.invalidResponse
        }
        return AICoachResponse(text: text, model: result.model)
    }

    private func bestFreeModel(apiKey: String) async -> String {
        var components = URLComponents(url: modelsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "sort", value: "intelligence-high-to-low")]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
              let catalog = try? JSONDecoder().decode(ModelCatalog.self, from: data) else { return fallbackModel }
        return catalog.data.first(where: { model in
            Decimal(string: model.pricing.prompt) == .zero &&
            Decimal(string: model.pricing.completion) == .zero &&
            (model.architecture?.inputModalities?.contains("text") ?? true)
        })?.id ?? fallbackModel
    }
}

private struct ChatRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    struct Provider: Encodable {
        let dataCollection: String
        enum CodingKeys: String, CodingKey { case dataCollection = "data_collection" }
    }
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let temperature: Double
    let provider: Provider
    enum CodingKeys: String, CodingKey { case model, messages, temperature, provider; case maxTokens = "max_tokens" }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: MessageContent }
        let message: Message
    }
    let model: String
    let choices: [Choice]
}

private enum MessageContent: Decodable {
    struct Part: Decodable { let text: String? }
    case value(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) { self = .value(text); return }
        let parts = try container.decode([Part].self)
        self = .value(parts.compactMap(\.text).joined(separator: "\n"))
    }

    var text: String {
        switch self { case let .value(text): text }
    }
}

private struct ErrorEnvelope: Decodable {
    struct APIError: Decodable { let message: String }
    let error: APIError
}

private struct ModelCatalog: Decodable {
    struct Model: Decodable {
        struct Pricing: Decodable { let prompt: String; let completion: String }
        struct Architecture: Decodable {
            let inputModalities: [String]?
            enum CodingKeys: String, CodingKey { case inputModalities = "input_modalities" }
        }
        let id: String
        let pricing: Pricing
        let architecture: Architecture?
    }
    let data: [Model]
}
