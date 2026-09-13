import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "circle.grid.2x2.fill") }
            AddFoodView().tabItem { Label("Log", systemImage: "plus.circle.fill") }
            LidlShoppingView().tabItem { Label("Shop", systemImage: "basket.fill") }
            WeeklyCoachView().tabItem { Label("Plan", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(.light)
    }
}
