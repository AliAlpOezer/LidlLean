import Foundation
import SwiftData

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let schema = Schema([Food.self, MealEntry.self, UserGoal.self, ShoppingItem.self, DayReview.self, WorkoutRecord.self])
let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
let context = ModelContext(container)
let food = Food(name: "Legacy oats", nutrientsPer100g: Nutrients(calories: 370, protein: 13, carbohydrates: 60, fat: 7))
food.labelConfirmed = true
context.insert(food)
context.insert(MealEntry(food: food, grams: 50, kind: .breakfast))
context.insert(ShoppingItem(offerID: "legacy-offer", name: food.name, unitPrice: 1.49, productURL: nil, imageURL: nil))
context.insert(UserGoal(calorieTarget: 2100, proteinTarget: 150))
try context.save()
print("Seeded a legacy journal")
