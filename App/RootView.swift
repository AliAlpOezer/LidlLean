import SwiftUI

struct RootView: View {
    @State private var healthSyncMessage: String?

    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "circle.grid.2x2.fill") }
            AddFoodView().tabItem { Label("Log", systemImage: "plus.circle.fill") }
            LidlShoppingView().tabItem { Label("Shop", systemImage: "basket.fill") }
            WeeklyCoachView().tabItem { Label("Plan", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .modifier(AppTabBarStyle())
        .background(AppTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "lidllean", url.host?.lowercased() == "health-sync" else { return }
            Task {
                do {
                    let summary = try await HealthImportStore.shared.importShortcut(url: url)
                    NotificationCenter.default.post(name: .healthDataDidChange, object: nil)
                    healthSyncMessage = "Imported \(summary.records) Health values for today."
                } catch {
                    healthSyncMessage = error.localizedDescription
                }
            }
        }
        .alert("Health sync", isPresented: Binding(get: { healthSyncMessage != nil }, set: { if !$0 { healthSyncMessage = nil } })) {
            Button("Done", role: .cancel) { healthSyncMessage = nil }
        } message: {
            Text(healthSyncMessage ?? "")
        }
    }
}

extension Notification.Name {
    static let healthDataDidChange = Notification.Name("LidlLean.healthDataDidChange")
}
