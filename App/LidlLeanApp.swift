import SwiftData
import SwiftUI

@main struct LidlLeanApp: App {
    private let container: ModelContainer = {
        if AppRuntime.isUITest { AppRuntime.preferences.removePersistentDomain(forName: "LidlLean.UITests") }
        let schema = Schema([Food.self, MealEntry.self, UserGoal.self, ShoppingItem.self, DayReview.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: AppRuntime.isUITest)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
    var body: some Scene {
        WindowGroup { RootView().defaultAppStorage(AppRuntime.preferences) }
            .modelContainer(container)
    }
}
