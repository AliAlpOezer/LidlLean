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
        var values = Nutrients(calories: kcal, protein: protein, carbohydrates: carbs, fat: fat)
        values.fiber = n.fiber
        values.salt = n.salt
        values.calcium = n.calcium.map { $0 * 1_000 }
        values.iron = n.iron.map { $0 * 1_000 }
        values.potassium = n.potassium.map { $0 * 1_000 }
        for nutrient in LabelNutrient.allCases {
            if let value = values[nutrient], !value.isFinite || value < 0 || value > nutrient.maximumPer100g {
                values[nutrient] = nil
            }
        }
        return FoodDraft(name: name, barcode: ean, nutrientsPer100g: values)
    }
}
private struct Response: Decodable { let status: Int; let product: Product? }
private struct Product: Decodable { let name: String?; let nutrients: Nutriment?; enum CodingKeys: String, CodingKey { case name = "product_name"; case nutrients = "nutriments" } }
private struct Nutriment: Decodable {
    let kcal: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let salt: Double?
    let calcium: Double?
    let iron: Double?
    let potassium: Double?
    enum CodingKeys: String, CodingKey {
        case kcal = "energy-kcal_100g", protein = "proteins_100g", carbs = "carbohydrates_100g", fat = "fat_100g"
        case fiber = "fiber_100g", salt = "salt_100g", calcium = "calcium_100g", iron = "iron_100g", potassium = "potassium_100g"
    }
}
