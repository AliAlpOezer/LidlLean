import SwiftData
import SwiftUI

@main struct LidlLeanApp: App {
    private let container: ModelContainer = try! ModelContainer(for: Food.self, MealEntry.self, UserGoal.self, ShoppingItem.self)
    var body: some Scene { WindowGroup { RootView() }.modelContainer(container) }
}
