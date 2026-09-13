import Foundation
import SwiftData

enum FoodSource: String, Codable { case manual, openFoodFacts }
enum MealKind: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Nutrients: Codable, Equatable {
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    static let zero = Nutrients(calories: 0, protein: 0, carbohydrates: 0, fat: 0)
    static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients { Nutrients(calories: lhs.calories + rhs.calories, protein: lhs.protein + rhs.protein, carbohydrates: lhs.carbohydrates + rhs.carbohydrates, fat: lhs.fat + rhs.fat) }
    func scaled(by factor: Double) -> Nutrients { Nutrients(calories: calories * factor, protein: protein * factor, carbohydrates: carbohydrates * factor, fat: fat * factor) }
}

@Model final class Food {
    @Attribute(.unique) var id: UUID
    var name: String
    var barcode: String?
    var nutrientsPer100g: Nutrients
    var source: FoodSource
    var verifiedAt: Date
    init(name: String, barcode: String? = nil, nutrientsPer100g: Nutrients, source: FoodSource = .manual) {
        id = UUID(); self.name = name; self.barcode = barcode; self.nutrientsPer100g = nutrientsPer100g; self.source = source; verifiedAt = .now
    }
}

@Model final class MealEntry {
    @Attribute(.unique) var id: UUID
    var foodName: String
    var grams: Double
    var nutrients: Nutrients
    var kind: MealKind
    var consumedAt: Date
    init(food: Food, grams: Double, kind: MealKind, consumedAt: Date = .now) {
        id = UUID(); foodName = food.name; self.grams = grams; nutrients = food.nutrientsPer100g.scaled(by: grams / 100); self.kind = kind; self.consumedAt = consumedAt
    }
}

@Model final class UserGoal {
    @Attribute(.unique) var id: UUID
    var calorieTarget: Double
    var proteinTarget: Double
    init(calorieTarget: Double = 2_000, proteinTarget: Double = 140) { id = UUID(); self.calorieTarget = calorieTarget; self.proteinTarget = proteinTarget }
}
