import SwiftData
import SwiftUI

@main struct LidlLeanApp: App {
    private let container: ModelContainer = {
        if AppRuntime.isUITest { AppRuntime.preferences.removePersistentDomain(forName: "LidlLean.UITests") }
        let schema = Schema([Food.self, MealEntry.self, UserGoal.self, ShoppingItem.self, DayReview.self, WorkoutRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: AppRuntime.isUITest)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        if AppRuntime.usesFixtures {
            let context = ModelContext(container)
            let oats = Food(name: "Test oats", nutrientsPer100g: Nutrients(calories: 370, protein: 13, carbohydrates: 60, fat: 7, fiber: 10, salt: 0, calcium: 50, iron: 4, potassium: 350))
            oats.labelConfirmed = true
            context.insert(oats)
            context.insert(UserGoal())
            AppRuntime.preferences.set(true, forKey: "plannerConfigured")
            try! context.save()
        }
        return container
    }()
    var body: some Scene {
        WindowGroup { RootView().defaultAppStorage(AppRuntime.preferences) }
            .modelContainer(container)
    }
}
