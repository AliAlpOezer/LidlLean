import Foundation

let completion = DispatchSemaphore(value: 0)
var failure: Error?
Task {
    do {
        let catalog = try await LidlCatalogClient().weeklyCatalog(forceRefresh: true)
        guard !catalog.offers.isEmpty, !catalog.pages.isEmpty else {
            fatalError("Lidl catalog returned no offers or flyer pages.")
        }
        print("Lidl catalog: \(catalog.offers.count) offers, \(catalog.pages.count) pages")
    } catch {
        failure = error
    }
    completion.signal()
}
completion.wait()
if let failure {
    fatalError("Lidl catalog smoke test failed: \(failure.localizedDescription)")
}
