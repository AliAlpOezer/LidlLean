import Charts
import SwiftData
import SwiftUI

struct WeeklyCoachView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MealEntry.consumedAt) private var entries: [MealEntry]
    @Query private var goals: [UserGoal]
    @Query private var reviews: [DayReview]
    @Query private var foods: [Food]
    @Query private var basket: [ShoppingItem]
    @AppStorage("plannerConfigured") private var configured = false
    @AppStorage("plannerAvoid") private var avoid = ""
    @AppStorage("weeklyWeightLossGoal") private var weightGoal = 1.0
    @State private var weights: [Date: Double] = [:]
    @State private var energy: [Date: (resting: Double?, active: Double?)] = [:]
    @State private var catalog: LidlWeeklyCatalog?
    @State private var errorMessage: String?
    @State private var offersMessage: String?
    @State private var settingsPresented = false
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var now = Date.now
    @State private var loading = false
    private let health = HealthKitClient()
    private let lidl = LidlCatalogClient()
    private var calendar: Calendar { .current }
    private var target: Double { goals.first?.calorieTarget ?? 0 }
    private var proteinTarget: Double { goals.first?.proteinTarget ?? 0 }

    private var history: [PlanningDay] {
        let today = calendar.startOfDay(for: now)
        return (-13...0).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let meals = entries.filter { calendar.isDate($0.consumedAt, inSameDayAs: day) }
            let signature = DayReview.signature(for: meals)
            let reviewed = reviews.contains { $0.day == day && $0.signature == signature }
            return PlanningDay(date: day, calories: meals.reduce(0) { $0 + $1.nutrients.calories },
                               protein: meals.reduce(0) { $0 + $1.nutrients.protein }, reviewed: reviewed,
                               restingEnergy: energy[day]?.resting, activeEnergy: energy[day]?.active)
        }
    }
    private var plan: WeeklyPlan {
        WeeklyPlanner.make(days: history, dailyCalories: target, dailyProtein: proteinTarget, now: now, calendar: calendar)
    }
    private var recommendations: [(food: Food, grams: Double, offer: LidlOffer?)] {
        guard configured else { return [] }
        let excluded = avoid.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var seen = Set<String>()
        return foods.compactMap { food -> (Food, Double, LidlOffer?)? in
            guard food.labelConfirmed, !excluded.contains(where: { food.name.localizedCaseInsensitiveContains($0) }),
                  seen.insert(food.name.lowercased()).inserted,
                  let grams = WeeklyPlanner.proteinPortion(proteinGap: plan.proteinRemainingToday,
                        caloriesLeft: plan.caloriesRemainingToday, caloriesPer100g: food.nutrientsPer100g.calories,
                        proteinPer100g: food.nutrientsPer100g.protein) else { return nil }
            let currentOffers = catalog.map { $0.validFrom <= now && $0.validUntil >= now } == true ? catalog?.offers ?? [] : []
            let offer = currentOffers.first { $0.title.caseInsensitiveCompare(food.name) == .orderedSame }
            return (food, grams, offer)
        }.sorted {
            let left = $0.0.nutrientsPer100g
            let right = $1.0.nutrientsPer100g
            return left.protein / left.calories > right.protein / right.calories
        }.prefix(5).map { (food: $0.0, grams: $0.1, offer: $0.2) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your week")
                            .font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                        Text("A live plan from your food log and Apple Health.")
                            .font(.subheadline).foregroundStyle(AppTheme.muted)
                    }
                    if !configured {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Set your weekly goal").font(.title2.bold())
                                Text("Choose your calorie budget and protein target to connect your food history to today's shopping suggestions.")
                                Button("Set up my plan") { settingsPresented = true }.buttonStyle(PrimaryActionStyle())
                            }
                        }
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.orange) }
                    yesterdayCard
                    weightCard
                    if configured { weekCard }
                    historyCard
                    if configured { recommendationsCard }
                }.padding()
            }
            .background(AppTheme.canvas)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Goals", systemImage: "slider.horizontal.3") { settingsPresented = true }
                }
            }
            .sheet(isPresented: $settingsPresented) { PlannerSettingsView() }
            .refreshable { await refresh() }
            .task { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refresh() } }
            }
        }
    }

    private var yesterdayCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "Yesterday")
                if let yesterday = plan.yesterday {
                    LabeledContent("Food logged", value: "\(Int(yesterday.calories)) kcal")
                    LabeledContent("Recorded resting + active", value: yesterday.expenditure.map { "\(Int($0)) kcal" } ?? "Unavailable")
                    if let deficit = yesterday.deficit {
                        Text(deficit >= 0 ? "Estimated deficit: \(Int(deficit)) kcal" : "Estimated surplus: \(Int(-deficit)) kcal")
                            .font(.title3.bold())
                        Text("Based on your reviewed food log and energy recorded in Apple Health. Device coverage affects this estimate.")
                            .font(.caption).foregroundStyle(AppTheme.muted)
                    } else {
                        Text(yesterday.reviewed ? "Energy data is missing. Connect Health and check that resting and active energy have records." : "Review yesterday's food log below before using it to calculate your weekly balance.")
                    }
                }
                Button("Connect or refresh Apple Health") {
                    Task {
                        do { try await health.requestAccess(); await refresh() }
                        catch { errorMessage = error.localizedDescription }
                    }
                }.disabled(loading)
            }
        }
    }

    private var weekCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "Monday to Sunday")
                Text("\(Int(plan.loggedThisWeek)) / \(Int(plan.weeklyTarget)) kcal").font(.title2.bold())
                ProgressView(value: min(plan.loggedThisWeek / max(plan.weeklyTarget, 1), 1))
                if let average = plan.remainingAverage {
                    Text("\(Int(average)) kcal/day would fit the remaining \(plan.remainingDays) days, including today.")
                    Text("This is budget arithmetic. Your daily target stays at \(Int(target)) kcal; yesterday does not automatically lower it.")
                        .font(.caption).foregroundStyle(AppTheme.muted)
                } else {
                    Text("\(plan.unreviewedDays) past day(s) need review before a remaining-week average can be calculated.")
                }
                Text("Today: \(Int(plan.proteinRemainingToday)) g protein and \(Int(plan.caloriesRemainingToday)) kcal remaining against your chosen targets.")
                Chart(plan.days) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Logged kcal", day.calories))
                        .foregroundStyle(day.reviewed ? AppTheme.lime : AppTheme.muted)
                    RuleMark(y: .value("Daily target", target)).foregroundStyle(AppTheme.orange)
                }
                .frame(height: 170)
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { value in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                Text("Blue: reviewed. Gray: incomplete or not reviewed.").font(.caption).foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var weightCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionEyebrow(title: "Weight trend")
                Text("Goal: \(weightGoal.formatted()) kg per week").font(.title3.bold())
                let today = calendar.startOfDay(for: now)
                let boundary = calendar.date(byAdding: .day, value: -6, to: today)!
                let recent = weights.filter { $0.key >= boundary }.values
                let previous = weights.filter { $0.key < boundary }.values
                if recent.count >= 3, previous.count >= 3 {
                    let change = previous.reduce(0, +) / Double(previous.count) - recent.reduce(0, +) / Double(recent.count)
                    Text("Weekly average change: \(change >= 0 ? "down" : "up") \(abs(change).formatted(.number.precision(.fractionLength(2)))) kg")
                    Text("Comparing the last seven calendar days with the previous seven. Each recorded day has equal weight.").font(.caption)
                } else {
                    Text("A trend needs at least three days of weight readings in each of the last two weeks. Available: \(recent.count) recent, \(previous.count) previous.")
                }
                Text("Protein stays at your chosen daily target. Short-term scale changes include water, so a weekly goal is not a guaranteed result.")
                    .font(.caption).foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var historyCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "Daily journal")
                DatePicker("Review day", selection: $selectedDay, in: history.first!.date...now, displayedComponents: .date)
                let meals = entries.filter { calendar.isDate($0.consumedAt, inSameDayAs: selectedDay) }
                ForEach(meals) { meal in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(meal.foodName)
                            Text("\(Int(meal.grams)) g · \(Int(meal.nutrients.calories)) kcal").font(.caption).foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        Button("Delete", role: .destructive) { delete(meal) }.font(.caption)
                    }
                }
                if meals.isEmpty { Text("No food logged for this day. You can backdate meals in Log.") }
                let reviewed = history.first { calendar.isDate($0.date, inSameDayAs: selectedDay) }?.reviewed == true
                Button(reviewed ? "Reopen this day's log" : "Confirm all food is logged") { review(meals, reopen: reviewed) }
                    .buttonStyle(.bordered)
                Text("Changing food entries reopens the day so weekly calculations stay accurate.").font(.caption).foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var recommendationsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionEyebrow(title: "What to buy next")
                if let yesterday = plan.yesterday, yesterday.reviewed, yesterday.protein < proteinTarget {
                    Text("Yesterday was \(Int(proteinTarget - yesterday.protein)) g below your protein target. Planning a protein source today may make that target easier to reach.")
                }
                Text("Each option fits today's remaining calorie allowance and helps close your protein gap. Choose an option; these are alternatives, not an instruction to buy all of them.")
                    .font(.subheadline)
                if recommendations.isEmpty {
                    Text(plan.proteinRemainingToday == 0 ? "Your protein target is met today." : "No suitable saved foods fit yet. Scan and check the foods you buy in Log to build your personal recommendation library.")
                }
                ForEach(recommendations, id: \.food.id) { recommendation in
                    let nutrients = recommendation.food.nutrientsPer100g.scaled(by: recommendation.grams / 100)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(recommendation.food.name).font(.headline)
                        Text("\(Int(recommendation.grams)) g · \(Int(nutrients.calories)) kcal · \(Int(nutrients.protein)) g protein")
                        Text(recommendation.offer.map { "Matching Lidl listing: \($0.price.formatted(.currency(code: "EUR"))) per listed item; check pack size." }
                             ?? "From your saved food label. Lidl price and availability unconfirmed.")
                            .font(.caption).foregroundStyle(AppTheme.muted)
                        Button("Add portion to shopping list") { add(recommendation) }
                            .disabled(basket.contains { $0.offerID == "plan:\(recommendation.food.id):\(calendar.startOfDay(for: now).timeIntervalSince1970)" })
                    }
                    Divider()
                }
                if let offersMessage { Text(offersMessage).font(.caption).foregroundStyle(AppTheme.muted) }
            }
        }
    }

    private func refresh() async {
        guard !loading else { return }
        if AppRuntime.isUITest { return }
        loading = true
        defer { loading = false }
        now = .now
        let start = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now))!
        do { energy = try await health.energyHistory(from: start, to: now, calendar: calendar); errorMessage = nil }
        catch { energy = [:]; errorMessage = "Health history could not be read: \(error.localizedDescription)" }
        do { weights = try await health.weightHistory(from: start, to: now, calendar: calendar) }
        catch { weights = [:]; errorMessage = "Weight history could not be read: \(error.localizedDescription)" }
        do { catalog = try await lidl.weeklyCatalog(); offersMessage = nil }
        catch { catalog = nil; offersMessage = "Lidl prices could not be refreshed. Saved-food suggestions are available." }
    }

    private func review(_ meals: [MealEntry], reopen: Bool) {
        let day = calendar.startOfDay(for: selectedDay)
        if let existing = reviews.first(where: { $0.day == day }) {
            if reopen { context.delete(existing) } else { existing.signature = DayReview.signature(for: meals) }
        } else { context.insert(DayReview(day: day, signature: DayReview.signature(for: meals))) }
        save()
    }
    private func delete(_ meal: MealEntry) { context.delete(meal); save() }
    private func save() {
        do { try context.save() } catch { context.rollback(); errorMessage = "Could not save: \(error.localizedDescription)" }
    }
    private func add(_ recommendation: (food: Food, grams: Double, offer: LidlOffer?)) {
        let id = "plan:\(recommendation.food.id):\(calendar.startOfDay(for: now).timeIntervalSince1970)"
        guard !basket.contains(where: { $0.offerID == id }) else { return }
        let item = ShoppingItem(offerID: id, name: recommendation.food.name, unitPrice: recommendation.offer?.price ?? 0,
                                productURL: recommendation.offer?.productURL?.absoluteString, imageURL: recommendation.offer?.imageURL?.absoluteString)
        item.priceKnown = recommendation.offer != nil
        item.nutritionConfirmed = true
        item.plannedGrams = recommendation.grams
        item.caloriesPer100g = recommendation.food.nutrientsPer100g.calories
        item.proteinPer100g = recommendation.food.nutrientsPer100g.protein
        context.insert(item)
        save()
    }
}
