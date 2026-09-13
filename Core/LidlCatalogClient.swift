import Foundation

struct LidlOffer: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let brand: String?
    let price: Double
    let imageURL: URL?
    let productURL: URL?
    let category: String?
}

struct LidlFlyerPage: Identifiable, Equatable, Sendable {
    let number: Int
    let imageURL: URL
    let altText: String?
    var id: Int { number }
}

struct LidlWeeklyCatalog: Equatable, Sendable {
    let title: String
    let validFrom: Date
    let validUntil: Date
    let flyerURL: URL
    let offers: [LidlOffer]
    let pages: [LidlFlyerPage]
    let fetchedAt: Date
}

enum LidlCatalogError: LocalizedError {
    case noCatalogMetadata, noApplicableFlyer, invalidFlyerURL, invalidResponse
    var errorDescription: String? {
        switch self {
        case .noCatalogMetadata: "Lidl's offers page did not contain its flyer catalog."
        case .noApplicableFlyer: "No current or upcoming Lidl flyer was found."
        case .invalidFlyerURL: "Lidl returned an invalid flyer link."
        case .invalidResponse: "Lidl's flyer service returned an invalid response."
        }
    }
}

actor LidlCatalogClient {
    static let officialProspectURL = URL(string: "https://www.lidl.de/c/online-prospekte/s10005610/")!
    private static let endpoint = URL(string: "https://endpoints.leaflets.schwarz/v4/flyer")!
    private let session: URLSession
    private let cacheURL: URL

    init(session: URLSession = .shared) {
        self.session = session
        cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "lidl-weekly-catalog.json")
    }

    func weeklyCatalog(forceRefresh: Bool = false, now: Date = .now) async throws -> LidlWeeklyCatalog {
        if !forceRefresh, let cached = try? loadCache(), now.timeIntervalSince(cached.fetchedAt) < 6 * 60 * 60 { return cached.catalog }
        do {
            let flyer = try await fetchApplicableFlyer(now: now)
            let catalog = try await fetchCatalog(flyer: flyer)
            try? saveCache(catalog)
            return catalog
        } catch {
            if let cached = try? loadCache() { return cached.catalog }
            throw error
        }
    }

    private func fetchApplicableFlyer(now: Date) async throws -> SaleEvent {
        let html = try await text(from: Self.officialProspectURL)
        let pattern = #"<script\s+type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let catalogs = regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match -> OfferCatalog? in
            guard let range = Range(match.range(at: 1), in: html) else { return nil }
            return try? decoder.decode(OfferCatalog.self, from: Data(html[range].utf8))
        }.filter { $0.type == "OfferCatalog" }
        guard !catalogs.isEmpty else { throw LidlCatalogError.noCatalogMetadata }
        let day = Calendar.current.startOfDay(for: now)
        let candidates = catalogs.flatMap(\.events).filter { $0.endDate >= day }.sorted { $0.startDate < $1.startDate }
        guard let result = candidates.first(where: { $0.startDate <= now && $0.endDate >= now }) ?? candidates.first else { throw LidlCatalogError.noApplicableFlyer }
        return result
    }

    private func fetchCatalog(flyer: SaleEvent) async throws -> LidlWeeklyCatalog {
        guard let identifier = Self.flyerIdentifier(from: flyer.url), var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false) else { throw LidlCatalogError.invalidFlyerURL }
        components.queryItems = [URLQueryItem(name: "flyer_identifier", value: identifier)]
        guard let url = components.url else { throw LidlCatalogError.invalidFlyerURL }
        let response = try JSONDecoder().decode(FlyerResponse.self, from: try await payload(from: url))
        guard response.success else { throw LidlCatalogError.invalidResponse }
        let offers = response.flyer.products.values.compactMap { product -> LidlOffer? in
            guard let priceText = product.price, let price = Double(priceText.replacingOccurrences(of: ",", with: ".")) else { return nil }
            return LidlOffer(id: product.productID ?? product.title, title: product.title, brand: product.brand, price: price, imageURL: product.image.flatMap(URL.init(string:)), productURL: product.url.flatMap(URL.init(string:)), category: product.wonCategoryPrimary ?? product.categoryPrimary)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let pages = response.flyer.pages.compactMap { page in page.image.flatMap(URL.init(string:)).map { LidlFlyerPage(number: page.number, imageURL: $0, altText: page.altText) } }.sorted { $0.number < $1.number }
        return LidlWeeklyCatalog(title: response.flyer.title, validFrom: flyer.startDate, validUntil: flyer.endDate, flyerURL: flyer.url, offers: offers, pages: pages, fetchedAt: .now)
    }

    private func payload(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 25)
        request.setValue("LidlLean/1.0 personal shopping planner", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw LidlCatalogError.invalidResponse }
        return data
    }

    private func text(from url: URL) async throws -> String {
        guard let value = String(data: try await payload(from: url), encoding: .utf8) else { throw LidlCatalogError.invalidResponse }
        return value
    }

    private static func flyerIdentifier(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let marker = parts.firstIndex(of: "ar"), marker > 0 else { return nil }
        return parts[marker - 1]
    }

    private func saveCache(_ catalog: LidlWeeklyCatalog) throws { try JSONEncoder().encode(CachedCatalog(catalog)).write(to: cacheURL, options: .atomic) }
    private func loadCache() throws -> CachedCatalog { try JSONDecoder().decode(CachedCatalog.self, from: Data(contentsOf: cacheURL)) }
}

private struct OfferCatalog: Decodable {
    let type: String; let events: [SaleEvent]
    enum CodingKeys: String, CodingKey { case type = "@type"; case events = "itemListElement" }
}
private struct SaleEvent: Decodable { let name: String; let url: URL; let startDate: Date; let endDate: Date }
private struct FlyerResponse: Decodable { let success: Bool; let flyer: FlyerPayload }
private struct FlyerPayload: Decodable { let title: String; let products: [String: FlyerProduct]; let pages: [FlyerPage] }
private struct FlyerProduct: Decodable {
    let productID: String?; let title: String; let brand: String?; let price: String?; let image: String?; let url: String?; let wonCategoryPrimary: String?; let categoryPrimary: String?
    enum CodingKeys: String, CodingKey { case productID = "productId"; case title; case brand; case price; case image; case url; case wonCategoryPrimary; case categoryPrimary }
}
private struct FlyerPage: Decodable { let number: Int; let image: String?; let altText: String? }

private struct CachedCatalog: Codable {
    let title: String; let validFrom: Date; let validUntil: Date; let flyerURL: URL; let offers: [CachedOffer]; let pages: [CachedPage]; let fetchedAt: Date
    init(_ catalog: LidlWeeklyCatalog) { title = catalog.title; validFrom = catalog.validFrom; validUntil = catalog.validUntil; flyerURL = catalog.flyerURL; offers = catalog.offers.map(CachedOffer.init); pages = catalog.pages.map(CachedPage.init); fetchedAt = catalog.fetchedAt }
    var catalog: LidlWeeklyCatalog { LidlWeeklyCatalog(title: title, validFrom: validFrom, validUntil: validUntil, flyerURL: flyerURL, offers: offers.map(\.offer), pages: pages.map(\.page), fetchedAt: fetchedAt) }
}
private struct CachedOffer: Codable {
    let id: String; let title: String; let brand: String?; let price: Double; let imageURL: URL?; let productURL: URL?; let category: String?
    init(_ value: LidlOffer) { id = value.id; title = value.title; brand = value.brand; price = value.price; imageURL = value.imageURL; productURL = value.productURL; category = value.category }
    var offer: LidlOffer { LidlOffer(id: id, title: title, brand: brand, price: price, imageURL: imageURL, productURL: productURL, category: category) }
}
private struct CachedPage: Codable {
    let number: Int; let imageURL: URL; let altText: String?
    init(_ value: LidlFlyerPage) { number = value.number; imageURL = value.imageURL; altText = value.altText }
    var page: LidlFlyerPage { LidlFlyerPage(number: number, imageURL: imageURL, altText: altText) }
}
