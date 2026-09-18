import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    checks += 1
}

let legacy = Data(#"{"calories":370,"protein":13,"carbohydrates":60,"fat":7}"#.utf8)
let old = try JSONDecoder().decode(Nutrients.self, from: legacy)
expect(LabelNutrient.allCases.allSatisfy { old[$0] == nil }, "Old journals must not acquire invented nutrient values")
let complete = Nutrients(calories: 370, protein: 13, carbohydrates: 60, fat: 7,
                         fiber: 10, salt: 0, calcium: 50, iron: 4, potassium: 350)
let serving = complete.scaled(by: 0.5)
expect(serving.calories == 185 && serving.fiber == 5 && serving.calcium == 25, "Grams and milligrams must scale with serving size")
expect(serving.salt == 0, "An explicit zero must stay measured, not unknown")
expect(old.scaled(by: 2).iron == nil, "Scaling must preserve unknown minerals")
let mixed = LabelNutrient.fiber.coverage(in: [serving, old])
expect(mixed.total == 5 && mixed.knownEntries == 1 && mixed.entries == 2 && !mixed.complete, "Partial coverage must expose which entries are known")
let zeros = LabelNutrient.salt.coverage(in: [serving, complete])
expect(zeros.total == 0 && zeros.complete, "Known zero is valid complete coverage")
expect(LabelNutrient.iron.coverage(in: []).total == nil, "Empty journal means unknown, not zero intake")
expect(LabelNutrient.iron.coverage(in: [old]).total == nil, "Missing values must not fabricate an intake")
var invalid = complete
invalid.iron = .nan
expect(LabelNutrient.iron.coverage(in: [invalid, serving]).knownEntries == 1, "Corrupt values must not pollute coverage")
let encoded = try JSONEncoder().encode(complete)
let decoded = try JSONDecoder().decode(Nutrients.self, from: encoded)
expect(decoded == complete, "Nutrients must survive persistence")
expect((complete + old).fiber == nil, "A complete total cannot be claimed after adding an unknown value")
let catalogJSON = Data(#"{"status":1,"product":{"product_name":"Label fixture","nutriments":{"energy-kcal_100g":100,"proteins_100g":10,"carbohydrates_100g":10,"fat_100g":2,"fiber_100g":3,"salt_100g":0,"calcium_100g":0.12,"calcium_unit":"mg","iron_100g":0.002,"potassium_100g":0.15}}}"#.utf8)
let imported = try OpenFoodFactsClient.decode(catalogJSON, barcode: "12345678").nutrientsPer100g
expect(imported.calcium == 120 && imported.iron == 2 && imported.potassium == 150, "OFF standard gram fields must convert to milligrams regardless of contributor display unit")
expect(imported.salt == 0 && imported.fiber == 3, "Salt and fibre stay in grams")
let missingJSON = Data(#"{"status":1,"product":{"product_name":"Partial label","nutriments":{"energy-kcal_100g":100,"proteins_100g":10,"carbohydrates_100g":10,"fat_100g":2,"fiber_100g":-1}}}"#.utf8)
let partial = try OpenFoodFactsClient.decode(missingJSON, barcode: "12345678").nutrientsPer100g
expect(partial.fiber == nil && partial.calcium == nil, "Invalid or missing optional catalog values must remain unknown")
print("Passed \(checks) nutrition checks")
