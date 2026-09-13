import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "chart.xyaxis.line") }
            AddFoodView().tabItem { Label("Log", systemImage: "plus.circle.fill") }
            LidlShoppingView().tabItem { Label("Plan", systemImage: "basket.fill") }
            WeeklyCoachView().tabItem { Label("Coach", systemImage: "sparkles") }
        }
        .tint(AppTheme.lime)
        .preferredColorScheme(.dark)
    }
}
