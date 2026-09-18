import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date.now
    @State private var healthSyncMessage: String?
    @State private var selection = AppTab.today
    @State private var visited: Set<AppTab> = [.today]

    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()
            ForEach(AppTab.allCases) { tab in
                if visited.contains(tab) || tab == selection {
                    page(for: tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(selection == tab ? 1 : 0)
                        .allowsHitTesting(selection == tab)
                        .accessibilityHidden(selection != tab)
                }
            }
        }
        .onChange(of: selection) { _, tab in visited.insert(tab) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in now = .now }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selection: $selection)
        }
        .overlay(alignment: .top) {
            GeometryReader { geometry in
                AppTheme.canvas
                    .frame(height: geometry.safeAreaInsets.top)
                    .offset(y: -geometry.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
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

    @ViewBuilder private func page(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayView(now: now, openLog: { selection = .log }, openTrain: { selection = .train },
                      openShop: { selection = .shop }, openPlan: { selection = .plan })
        case .log: AddFoodView()
        case .shop: LidlShoppingView()
        case .plan: WeeklyCoachView()
        case .train: TrainingView(now: now)
        }
    }
}

private struct AppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol).font(.headline.weight(.bold))
                        Text(tab.title).font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(selection == tab ? AppTheme.ink : AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selection == tab ? AppTheme.lime : .clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(AppTheme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.stroke).frame(height: 1) }
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case today, log, shop, plan, train

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .today: "circle.grid.2x2.fill"
        case .log: "plus.circle.fill"
        case .shop: "basket.fill"
        case .plan: "chart.line.uptrend.xyaxis"
        case .train: "figure.strengthtraining.traditional"
        }
    }
}

extension Notification.Name {
    static let healthDataDidChange = Notification.Name("LidlLean.healthDataDidChange")
}
