import Foundation

struct Nutrients: Codable, Equatable {
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var fiber: Double? = nil
    var salt: Double? = nil
    var calcium: Double? = nil
    var iron: Double? = nil
    var potassium: Double? = nil

    static let zero = Nutrients(calories: 0, protein: 0, carbohydrates: 0, fat: 0)

    static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        var result = Nutrients(calories: lhs.calories + rhs.calories, protein: lhs.protein + rhs.protein,
                              carbohydrates: lhs.carbohydrates + rhs.carbohydrates, fat: lhs.fat + rhs.fat)
        for nutrient in LabelNutrient.allCases {
            if let left = lhs[nutrient], let right = rhs[nutrient] { result[nutrient] = left + right }
        }
        return result
    }

    func scaled(by factor: Double) -> Nutrients {
        var result = Nutrients(calories: calories * factor, protein: protein * factor,
                              carbohydrates: carbohydrates * factor, fat: fat * factor)
        for nutrient in LabelNutrient.allCases { result[nutrient] = self[nutrient].map { $0 * factor } }
        return result
    }

    subscript(nutrient: LabelNutrient) -> Double? {
        get {
            switch nutrient {
            case .fiber: fiber
            case .salt: salt
            case .calcium: calcium
            case .iron: iron
            case .potassium: potassium
            }
        }
        set {
            switch nutrient {
            case .fiber: fiber = newValue
            case .salt: salt = newValue
            case .calcium: calcium = newValue
            case .iron: iron = newValue
            case .potassium: potassium = newValue
            }
        }
    }
}

enum LabelNutrient: String, CaseIterable, Identifiable {
    case fiber, salt, calcium, iron, potassium
    var id: Self { self }
    var title: String { self == .fiber ? "Fibre" : rawValue.capitalized }
    var unit: String { self == .fiber || self == .salt ? "g" : "mg" }
    var maximumPer100g: Double { unit == "g" ? 100 : 100_000 }

    func coverage(in meals: [Nutrients]) -> NutrientCoverage {
        let known = meals.compactMap { $0[self] }.filter { $0.isFinite && $0 >= 0 }
        return NutrientCoverage(total: known.isEmpty ? nil : known.reduce(0, +), knownEntries: known.count, entries: meals.count)
    }
}

struct NutrientCoverage {
    let total: Double?
    let knownEntries: Int
    let entries: Int
    var complete: Bool { entries > 0 && knownEntries == entries }
}
