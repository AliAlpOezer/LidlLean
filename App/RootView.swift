import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "chart.xyaxis.line") }
            AddFoodView().tabItem { Label("Log", systemImage: "plus.circle.fill") }
            ShoppingView().tabItem { Label("Plan", systemImage: "basket.fill") }
            CoachView().tabItem { Label("Coach", systemImage: "sparkles") }
        }
        .tint(AppTheme.lime)
        .preferredColorScheme(.dark)
    }
}
