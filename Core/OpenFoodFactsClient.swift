import Foundation

struct FoodDraft { let name: String; let barcode: String; let nutrientsPer100g: Nutrients }
enum FoodLookupError: LocalizedError { case invalidBarcode, notFound, incomplete; var errorDescription: String? { switch self { case .invalidBarcode: "Enter a valid barcode."; case .notFound: "Not found. Add it manually."; case .incomplete: "Nutrition data is incomplete. Add it manually." } } }
actor OpenFoodFactsClient {
    func lookup(barcode: String) async throws -> FoodDraft {
        let ean = barcode.filter(\.isNumber)
        guard (8...14).contains(ean.count), let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(ean).json") else { throw FoodLookupError.invalidBarcode }
        var request = URLRequest(url: url); request.setValue("LidlLean/1.0 personal nutrition logger", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FoodLookupError.notFound }
        let payload = try JSONDecoder().decode(Response.self, from: data)
        guard payload.status == 1, let p = payload.product, let name = p.name, let n = p.nutrients, let kcal = n.kcal, let protein = n.protein, let carbs = n.carbs, let fat = n.fat else { throw FoodLookupError.incomplete }
        return FoodDraft(name: name, barcode: ean, nutrientsPer100g: Nutrients(calories: kcal, protein: protein, carbohydrates: carbs, fat: fat))
    }
}
private struct Response: Decodable { let status: Int; let product: Product? }
private struct Product: Decodable { let name: String?; let nutrients: Nutriment?; enum CodingKeys: String, CodingKey { case name = "product_name"; case nutrients = "nutriments" } }
private struct Nutriment: Decodable { let kcal: Double?; let protein: Double?; let carbs: Double?; let fat: Double?; enum CodingKeys: String, CodingKey { case kcal = "energy-kcal_100g"; case protein = "proteins_100g"; case carbs = "carbohydrates_100g"; case fat = "fat_100g" } }
