import SwiftUI

struct RootView: View {
    @State private var healthSyncMessage: String?
    @State private var selection = AppTab.today

    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()
            Group {
                switch selection {
                case .today:
                    TodayView { selection = .log }
                case .log:
                    AddFoodView()
                case .shop:
                    LidlShoppingView()
                case .plan:
                    WeeklyCoachView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selection: $selection)
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
        .background(AppTheme.surface.opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.stroke).frame(height: 1) }
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case today, log, shop, plan

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .today: "circle.grid.2x2.fill"
        case .log: "plus.circle.fill"
        case .shop: "basket.fill"
        case .plan: "chart.line.uptrend.xyaxis"
        }
    }
}

extension Notification.Name {
    static let healthDataDidChange = Notification.Name("LidlLean.healthDataDidChange")
}
