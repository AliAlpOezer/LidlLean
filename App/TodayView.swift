import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.consumedAt, order: .reverse) private var entries: [MealEntry]
    @Query private var goals: [UserGoal]
    @Query private var reviews: [DayReview]
    @Query private var workouts: [WorkoutRecord]
    @AppStorage("plannerConfigured") private var configured = false
    @AppStorage("training.programStart") private var startTimestamp = 0.0
    @State private var settingsPresented = false
    @State private var activity = ActivitySnapshot.unavailable
    @State private var healthError: String?
    @State private var healthImportMessage: String?
    @State private var importingHealthXML = false
    private let health = HealthKitClient()
    let now: Date
    let openLog: () -> Void
    let openTrain: () -> Void
    let openShop: () -> Void
    let openPlan: () -> Void

    private var today: [MealEntry] { entries.filter { Calendar.current.isDate($0.consumedAt, inSameDayAs: now) } }
    private var totals: Nutrients { today.reduce(.zero) { $0 + $1.nutrients } }
    private var goal: UserGoal { goals.first ?? UserGoal() }
    private var momentum: MomentumSnapshot {
        MomentumEngine.snapshot(for: momentumDay(for: now), history: momentumHistory, proteinTarget: goal.proteinTarget, calendar: .current)
    }
    private var momentumHistory: [MomentumDay] {
        let calendar = Calendar.current
        return (-13...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            return momentumDay(for: date)
        }
    }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    if configured { energyCard } else { setupCard }
                    quickActions
                    trainingCard
                    nutritionCard
                    mealsCard
                    momentumCard
                    healthCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .accessibilityIdentifier("todayScreen")
            .task {
                guard !AppRuntime.isUITest else { return }
                activity = await health.todaySnapshot()
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthDataDidChange)) { _ in
                Task { activity = await health.todaySnapshot() }
            }
            .sheet(isPresented: $settingsPresented) { PlannerSettingsView() }
            .fileImporter(isPresented: $importingHealthXML, allowedContentTypes: [.xml], allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                Task {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let summary = try await HealthImportStore.shared.importXML(from: url)
                        activity = await health.todaySnapshot()
                        healthImportMessage = "Imported \(summary.records) records across \(summary.days) days."
                        NotificationCenter.default.post(name: .healthDataDidChange, object: nil)
                    } catch {
                        healthImportMessage = error.localizedDescription
                    }
                }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.success)
                Text(greeting)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(today.isEmpty ? "Start with your first meal." : "\(today.count) meal\(today.count == 1 ? "" : "s") logged so far.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 12)
            Image(systemName: "leaf.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 48, height: 48)
                .background(AppTheme.lime, in: Circle())
        }
        .padding(.top, 14)
    }

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("TODAY'S FUEL", systemImage: "leaf.fill").font(.caption.weight(.bold)).tracking(1.1)
                Spacer()
                Button { settingsPresented = true } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Edit nutrition targets")
            }
            .foregroundStyle(AppTheme.lime)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { energyMetric; proteinMetric }
                VStack(alignment: .leading, spacing: 20) { energyMetric; proteinMetric }
            }
            HStack(spacing: 18) {
                Text("\(Int(totals.carbohydrates)) g carbs")
                Text("\(Int(totals.fat)) g fat")
            }
            .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.72))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [AppTheme.hero, AppTheme.primary.opacity(0.92)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private var energyMetric: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(abs(goal.calorieTarget - totals.calories), format: .number.precision(.fractionLength(0)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(.white)
            Text(totals.calories > goal.calorieTarget ? "kcal above target" : "kcal remaining")
                .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.78))
            ProgressView(value: min(totals.calories / max(goal.calorieTarget, 1), 1)).tint(AppTheme.lime)
            Text("\(Int(totals.calories)) / \(Int(goal.calorieTarget)) kcal")
                .font(.caption).foregroundStyle(.white.opacity(0.68))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var proteinMetric: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(Int(totals.protein)) g").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(AppTheme.lime)
            Text("protein today").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.78))
            ProgressView(value: min(totals.protein / max(goal.proteinTarget, 1), 1)).tint(AppTheme.lime)
            Text("\(Int(max(0, goal.proteinTarget - totals.protein))) g to your \(Int(goal.proteinTarget)) g target")
                .font(.caption).foregroundStyle(.white.opacity(0.68))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var setupCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "Your routine, your targets")
                Text("Make room for a stronger you.").font(.title2.bold()).foregroundStyle(AppTheme.ink)
                Text("Choose your nutrition targets to see your daily progress. You can log food and train right away.")
                    .font(.subheadline).foregroundStyle(AppTheme.muted)
                Button("Set my targets") { settingsPresented = true }.buttonStyle(PrimaryActionStyle())
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button(action: openLog) {
                Label("Log food", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
            Button(action: openShop) {
                Label("Shop", systemImage: "basket").frame(minWidth: 70)
            }
            .buttonStyle(QuietActionStyle())
            .accessibilityLabel("Open shopping list")
        }
    }

    private var trainingCard: some View {
        let start = Date(timeIntervalSince1970: startTimestamp)
        let session = startTimestamp > 0 ? TrainingProgram.session(for: now, startDate: start) : nil
        let dayID = TrainingProgram.dayID(for: now, startDate: start)
        let completed = startTimestamp > 0 && workouts.contains { $0.programDayID == dayID }
        return Button(action: openTrain) {
            HStack(spacing: 14) {
                Image(systemName: completed ? "checkmark" : "figure.strengthtraining.traditional")
                    .font(.title3.weight(.bold)).frame(width: 48, height: 48)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(completed ? "Training logged" : session?.title ?? (startTimestamp == 0 ? "Start your strength routine" : "Time to recover"))
                        .font(.headline)
                    Text(completed ? "Your session is saved. Nice work." : session.map { "\($0.durationMinutes) min · View today's session" } ?? "Your four-week training companion")
                        .font(.caption).foregroundStyle(AppTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.subheadline.weight(.bold))
            }
            .foregroundStyle(AppTheme.ink).padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityIdentifier("todayTraining")
    }

    private var nutritionCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(title: "Beyond macros")
                Text("Know what fuels you.").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                if today.contains(where: { meal in LabelNutrient.allCases.contains { meal.nutrients[$0] != nil } }) {
                    ForEach(LabelNutrient.allCases) { nutrient in
                        let coverage = nutrient.coverage(in: today.map(\.nutrients))
                        HStack {
                            Text(nutrient.title).font(.subheadline.weight(.medium))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(coverage.total.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(nutrient.unit)" } ?? "Unknown")
                                    .font(.subheadline.weight(.semibold))
                                if coverage.total != nil {
                                    Text(coverage.complete ? "All logged foods" : "\(coverage.knownEntries) of \(coverage.entries) foods · partial")
                                        .font(.caption2).foregroundStyle(AppTheme.muted)
                                }
                            }
                        }.foregroundStyle(AppTheme.ink)
                    }
                    Text("Known label amounts only. Missing values are not zero, and logged totals do not measure dietary adequacy.")
                        .font(.caption).foregroundStyle(AppTheme.muted)
                } else {
                    Text("Add fibre, salt and minerals from your food labels when you log. Their daily totals will appear here.")
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                }
            }
        }
    }

    private var momentumCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionEyebrow(title: "Daily momentum")
                        Text(momentum.completedMissions == 3 ? "Day closed. Great work." : "Build today’s win.")
                            .font(.title3.bold()).foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    VStack(spacing: 1) {
                        Label("\(momentum.streak)", systemImage: "flame.fill")
                            .font(.headline.weight(.bold)).foregroundStyle(AppTheme.warning)
                        Text("day streak").font(.caption2.weight(.bold)).foregroundStyle(AppTheme.muted)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                HStack(spacing: 9) {
                    ForEach(momentum.missions) { mission in
                        VStack(alignment: .leading, spacing: 7) {
                            Image(systemName: mission.complete ? "checkmark.circle.fill" : mission.symbol)
                                .font(.headline).foregroundStyle(mission.complete ? AppTheme.success : AppTheme.muted)
                            Text(mission.title).font(.caption.weight(.bold)).foregroundStyle(AppTheme.ink).lineLimit(2)
                            ProgressView(value: mission.progress).tint(mission.complete ? AppTheme.success : AppTheme.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                HStack {
                    Label("\(momentum.points) / \(MomentumEngine.pointsPerLevel) momentum", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("Level \(momentum.level)").font(.caption.weight(.bold)).foregroundStyle(AppTheme.success)
                }
                Button("Review my day", action: openPlan).buttonStyle(QuietActionStyle())
            }
        }
    }

    private func momentumDay(for date: Date) -> MomentumDay {
        let calendar = Calendar.current
        let meals = entries.filter { calendar.isDate($0.consumedAt, inSameDayAs: date) }
        let reviewed = reviews.contains { calendar.isDate($0.day, inSameDayAs: date) }
        return MomentumDay(date: date, mealCount: meals.count, protein: meals.reduce(0) { $0 + $1.nutrients.protein }, reviewed: reviewed)
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
                        .background(AppTheme.health, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    HealthMetric(label: "Steps", value: activity.steps.map { "\(Int($0))" } ?? "Not shared")
                    HealthMetric(label: "Active", value: activity.activeEnergy.map { "\(Int($0)) kcal" } ?? "Not shared")
                    HealthMetric(label: "Resting", value: activity.basalEnergy.map { "\(Int($0)) kcal" } ?? "Not shared")
                    HealthMetric(label: "Weight", value: activity.weight.map { String(format: "%.1f kg", $0) } ?? "Not shared")
                    HealthMetric(label: "Distance", value: activity.walkingDistance.map { String(format: "%.1f km", $0) } ?? "Not shared")
                    HealthMetric(label: "Exercise", value: activity.exerciseMinutes.map { "\(Int($0)) min" } ?? "Not shared")
                }
                if let healthError {
                    Label(healthError, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Connect or refresh Apple Health", systemImage: "heart.text.square") {
                    Task { await connectHealth() }
                }
                .buttonStyle(PrimaryActionStyle())
                Button("Import Health export", systemImage: "arrow.down.doc") {
                    importingHealthXML = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                if let healthImportMessage {
                    Text(healthImportMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case ..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private func connectHealth() async {
        do { try await health.requestAccess(); activity = await health.todaySnapshot(); healthError = nil }
        catch { healthError = HealthKitClient.userFacingError(error) }
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
