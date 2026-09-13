import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealEntry.consumedAt, order: .reverse) private var entries: [MealEntry]
    @Query private var goals: [UserGoal]
    @State private var activity = ActivitySnapshot.unavailable
    @State private var healthError: String?
    private let health = HealthKitClient()

    private var today: [MealEntry] { entries.filter { Calendar.current.isDateInToday($0.consumedAt) } }
    private var totals: Nutrients { today.reduce(.zero) { $0 + $1.nutrients } }
    private var goal: UserGoal { goals.first ?? UserGoal() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    progressCard
                    macroGrid
                    activityCard
                    entriesCard
                }
                .padding(16)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("LIDLLEAN").font(.caption.weight(.black)).tracking(2).foregroundStyle(AppTheme.lime) } }
            .task { if goals.isEmpty { modelContext.insert(UserGoal()) }; activity = await health.todaySnapshot() }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide))).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.muted)
                Text("Own today.").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
            }
            Spacer()
            Image(systemName: "bolt.fill").font(.title2).foregroundStyle(AppTheme.canvas).padding(13).background(AppTheme.lime, in: Circle())
        }
    }

    private var progressCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) { Text("ENERGY").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(AppTheme.muted); Spacer(); Text("\(Int(max(goal.calorieTarget - totals.calories, 0))) left").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.lime) }
                Text("\(Int(totals.calories))").font(.system(size: 58, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink) + Text(" kcal").font(.title3.weight(.bold)).foregroundStyle(AppTheme.muted)
                ProgressView(value: min(totals.calories / max(goal.calorieTarget, 1), 1)).tint(AppTheme.lime).scaleEffect(x: 1, y: 2, anchor: .center)
                Text("Target \(Int(goal.calorieTarget)) kcal").font(.footnote).foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var macroGrid: some View {
        HStack(spacing: 10) {
            MacroTile(label: "PROTEIN", value: totals.protein, target: goal.proteinTarget, color: AppTheme.lime)
            MacroTile(label: "CARBS", value: totals.carbohydrates, target: nil, color: AppTheme.orange)
            MacroTile(label: "FAT", value: totals.fat, target: nil, color: .pink)
        }
    }

    private var activityCard: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                Image(systemName: "figure.walk").font(.title2.weight(.semibold)).foregroundStyle(AppTheme.canvas).padding(12).background(AppTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACTIVITY CONTEXT").font(.caption.weight(.bold)).tracking(1).foregroundStyle(AppTheme.muted)
                    Text(activity.steps.map { "\(Int($0)) steps · \(Int(activity.activeEnergy ?? 0)) active kcal" } ?? "Connect Apple Health for activity context").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.ink)
                    if let healthError { Text(healthError).font(.caption).foregroundStyle(.red) }
                }
                Spacer()
                Button("Connect") { Task { await connectHealth() } }.buttonStyle(.bordered).tint(AppTheme.lime).foregroundStyle(AppTheme.canvas)
            }
        }
    }

    private var entriesCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("TODAY'S LOG").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(AppTheme.muted)
                if today.isEmpty { Text("No entries yet. Start with the + Log tab.").foregroundStyle(AppTheme.muted) }
                ForEach(today) { entry in
                    HStack { VStack(alignment: .leading) { Text(entry.foodName).fontWeight(.semibold); Text("\(entry.kind.title) · \(Int(entry.grams)) g").font(.caption).foregroundStyle(AppTheme.muted) }; Spacer(); Text("\(Int(entry.nutrients.calories)) kcal").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink) }
                }
            }
        }
    }

    private func connectHealth() async { do { try await health.requestAccess(); activity = await health.todaySnapshot(); healthError = nil } catch { healthError = error.localizedDescription } }
}

private struct MacroTile: View {
    let label: String; let value: Double; let target: Double?; let color: Color
    var body: some View { VStack(alignment: .leading, spacing: 8) { Circle().fill(color).frame(width: 8, height: 8); Text(label).font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(AppTheme.muted); Text("\(Int(value))g").font(.title3.weight(.bold)).foregroundStyle(AppTheme.ink); Text(target.map { "/ \(Int($0))g" } ?? "today").font(.caption).foregroundStyle(AppTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
}
