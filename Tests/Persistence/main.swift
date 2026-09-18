import Foundation
import SwiftData

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let schema = Schema([Food.self, MealEntry.self, UserGoal.self, ShoppingItem.self, DayReview.self, WorkoutRecord.self])
let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
let context = ModelContext(container)
let meals = try context.fetch(FetchDescriptor<MealEntry>())
precondition(meals.count == 1 && meals[0].nutrients.calories == 185, "Legacy meal snapshot must survive")
precondition(meals[0].nutrients.fiber == nil, "Legacy nutrients must stay unknown")
let goals = try context.fetch(FetchDescriptor<UserGoal>())
precondition(goals.first?.calorieTarget == 2100 && goals.first?.proteinTarget == 150, "Existing targets must survive")
let basket = try context.fetch(FetchDescriptor<ShoppingItem>())
precondition(basket.count == 1 && basket[0].purchasedAt == nil && basket[0].coverageDays == 1, "Basket additions must migrate with neutral defaults")
basket[0].purchasedAt = Date(timeIntervalSince1970: 123456)
basket[0].coverageDays = 3
let foods = try context.fetch(FetchDescriptor<Food>())
foods[0].nutrientsPer100g.fiber = 10
context.insert(MealEntry(food: foods[0], grams: 200, kind: .lunch))
try context.save()
let reread = ModelContext(container)
let saved = try reread.fetch(FetchDescriptor<MealEntry>())
precondition(saved.count == 2 && saved.contains { $0.nutrients.fiber == 20 }, "New nutrient snapshots must persist")
precondition(saved.contains { $0.nutrients.calories == 185 && $0.nutrients.fiber == nil }, "Label changes must not rewrite old meals")
let savedBasket = try reread.fetch(FetchDescriptor<ShoppingItem>())
precondition(savedBasket[0].coverageDays == 3 && savedBasket[0].purchasedAt != nil, "Checklist changes must persist")
print("Passed legacy-store migration and journal persistence checks")
