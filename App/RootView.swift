import SwiftUI

struct RootView: View {
    @State private var healthSyncMessage: String?
    @State private var selection = AppTab.today

    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()
            TabView(selection: $selection) {
                TodayView { selection = .log }
                    .tabItem { Label("Today", systemImage: "circle.grid.2x2.fill") }
                    .tag(AppTab.today)
                AddFoodView()
                    .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                    .tag(AppTab.log)
                LidlShoppingView()
                    .tabItem { Label("Shop", systemImage: "basket.fill") }
                    .tag(AppTab.shop)
                WeeklyCoachView()
                    .tabItem { Label("Plan", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(AppTab.plan)
            }
            .modifier(AppTabBarStyle())
            .preferredColorScheme(.light)
        }
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

private enum AppTab: Hashable {
    case today, log, shop, plan
}

extension Notification.Name {
    static let healthDataDidChange = Notification.Name("LidlLean.healthDataDidChange")
}
