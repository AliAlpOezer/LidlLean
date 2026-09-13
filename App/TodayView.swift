import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.consumedAt, order: .reverse) private var entries: [MealEntry]
    @Query private var goals: [UserGoal]
    @State private var activity = ActivitySnapshot.unavailable
    @State private var healthError: String?
    private let health = HealthKitClient()

    private var today: [MealEntry] { entries.filter { Calendar.current.isDateInToday($0.consumedAt) } }
    private var totals: Nutrients { today.reduce(.zero) { $0 + $1.nutrients } }
    private var goal: UserGoal { goals.first ?? UserGoal() }
    private var caloriesLeft: Double { max(goal.calorieTarget - totals.calories, 0) }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    energyCard
                    macroGrid
                    healthCard
                    mealsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .accessibilityIdentifier("todayScreen")
            .navigationBarHidden(true)
            .task {
                if goals.isEmpty { context.insert(UserGoal()) }
                guard !AppRuntime.isUITest else { return }
                activity = await health.todaySnapshot()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text("Today")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            Text("Eat with intent. Keep protein protected.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.top, 18)
    }

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("ENERGY BUDGET").font(.caption.weight(.bold)).tracking(1.1)
                Spacer()
                Text("\(Int(caloriesLeft)) left").font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.82))
            HStack(alignment: .lastTextBaseline, spacing: 7) {
                Text("\(Int(totals.calories))").font(.system(size: 52, weight: .bold, design: .rounded))
                Text("kcal eaten").font(.headline).foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            ProgressView(value: min(totals.calories / max(goal.calorieTarget, 1), 1))
                .tint(.white).scaleEffect(x: 1, y: 1.6, anchor: .center)
            Text("Daily target \(Int(goal.calorieTarget)) kcal")
                .font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.72))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [AppTheme.ink, Color(red: 0.08, green: 0.23, blue: 0.50)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: AppTheme.ink.opacity(0.18), radius: 18, y: 9)
    }

    private var macroGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MacroTile(label: "Protein", value: totals.protein, target: goal.proteinTarget,
                      color: AppTheme.success, symbol: "dumbbell.fill")
            MacroTile(label: "Carbs", value: totals.carbohydrates, target: nil,
                      color: AppTheme.primary, symbol: "bolt.fill")
            MacroTile(label: "Fat", value: totals.fat, target: nil,
                      color: AppTheme.warning, symbol: "drop.fill")
            MacroTile(label: "Meals", value: Double(today.count), target: nil,
                      color: Color.purple, symbol: "fork.knife", unit: "")
        }
    }

    private var healthCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionEyebrow(title: "Apple Health")
                        Text("Movement and body data").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    HealthMetric(label: "Steps", value: activity.steps.map { "\(Int($0))" } ?? "Not shared")
                    HealthMetric(label: "Active", value: activity.activeEnergy.map { "\(Int($0)) kcal" } ?? "Not shared")
                    HealthMetric(label: "Resting", value: activity.basalEnergy.map { "\(Int($0)) kcal" } ?? "Not shared")
                    HealthMetric(label: "Weight", value: activity.weight.map { String(format: "%.1f kg", $0) } ?? "Not shared")
                    HealthMetric(label: "Distance", value: activity.walkingDistance.map { String(format: "%.1f km", $0) } ?? "Not shared")
                    HealthMetric(label: "Exercise", value: activity.exerciseMinutes.map { "\(Int($0)) min" } ?? "Not shared")
                }
                if let healthError { Text(healthError).font(.footnote).foregroundStyle(.red) }
                Button("Connect or refresh Apple Health", systemImage: "heart.text.square") {
                    Task { await connectHealth() }
                }
                .buttonStyle(PrimaryActionStyle())
            }
        }
    }

    private var mealsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(title: "Food log")
                HStack {
                    Text("Today's meals").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("\(today.count)").font(.headline).foregroundStyle(AppTheme.primary)
                }
                if today.isEmpty {
                    Label("Nothing logged yet. Use Log to scan or add food.", systemImage: "fork.knife")
                        .font(.subheadline).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
                }
                ForEach(today) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.kind.symbol)
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.foodName).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                            Text("\(entry.kind.title) · \(Int(entry.grams)) g").font(.caption).foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        Text("\(Int(entry.nutrients.calories)) kcal")
                            .font(.caption.weight(.bold)).foregroundStyle(AppTheme.ink)
                        Button(role: .destructive) { delete(entry) } label: {
                            Image(systemName: "trash").frame(width: 32, height: 44)
                        }
                    }
                }
            }
        }
    }

    private func connectHealth() async {
        do { try await health.requestAccess(); activity = await health.todaySnapshot(); healthError = nil }
        catch { healthError = error.localizedDescription }
    }

    private func delete(_ entry: MealEntry) {
        context.delete(entry)
        do { try context.save() }
        catch { context.rollback(); healthError = "Could not save: \(error.localizedDescription)" }
    }
}

private struct HealthMetric: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(AppTheme.muted)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MacroTile: View {
    let label: String
    let value: Double
    let target: Double?
    let color: Color
    let symbol: String
    var unit = "g"
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
                .frame(width: 32, height: 32).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(value))\(unit)").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                if let target { Text("/ \(Int(target))g").font(.caption).foregroundStyle(AppTheme.muted) }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.045)) }
    }
}
