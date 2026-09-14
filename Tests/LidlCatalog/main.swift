import Foundation

@main
struct LidlCatalogSmokeTest {
    static func main() async {
        do {
            let catalog = try await LidlCatalogClient().weeklyCatalog(forceRefresh: true)
            guard !catalog.offers.isEmpty, !catalog.pages.isEmpty else {
                fatalError("Lidl catalog returned no offers or flyer pages.")
            }
            print("Lidl catalog: \(catalog.offers.count) offers, \(catalog.pages.count) pages")
        } catch {
            fatalError("Lidl catalog smoke test failed: \(error.localizedDescription)")
        }
    }
}
