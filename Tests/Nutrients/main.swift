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
print("Passed \(checks) nutrition checks")
