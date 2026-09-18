import SwiftData
import SwiftUI

struct AddFoodView: View {
    private enum CaptureMode: String, CaseIterable, Identifiable {
        case scan, search, manual
        var id: Self { self }
        var title: String {
            switch self {
            case .scan: "Scan"
            case .search: "Barcode"
            case .manual: "Manual"
            }
        }
        var icon: String {
            switch self {
            case .scan: "barcode.viewfinder"
            case .search: "magnifyingglass"
            case .manual: "square.and.pencil"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Food.verifiedAt, order: .reverse) private var foods: [Food]
    @Query(sort: \MealEntry.consumedAt, order: .reverse) private var entries: [MealEntry]
    @Query private var goals: [UserGoal]
    @State private var name = ""
    @State private var barcode = ""
    @State private var grams = 100.0
    @State private var calories = 0.0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var labelValues: [LabelNutrient: String] = [:]
    @State private var kind: MealKind = .snack
    @State private var message: String?
    @State private var showingScanner = false
    @State private var consumedAt = Date.now
    @State private var source: FoodSource = .manual
    @State private var lookingUp = false
    @State private var confirmedLabel = false
    @State private var mode: CaptureMode = .scan
    @State private var celebration: MealCelebration?
    private let catalog = OpenFoodFactsClient()

    var body: some View {
        ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    modePicker
                    captureCard
                    if !foods.isEmpty { recentFoods }
                    productCard
                    nutritionCard
                    extraNutritionCard
                    mealCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(valid && confirmedLabel ? "Log this meal" : "Complete nutrition details")
                        Spacer()
                        Text("\(Int(scaledCalories)) kcal")
                    }
                }
                .buttonStyle(PrimaryActionStyle())
                .accessibilityIdentifier("saveMeal")
                .disabled(!valid || !confirmedLabel || lookingUp)
                .opacity(valid && confirmedLabel && !lookingUp ? 1 : 0.48)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScanner {
                    barcode = $0
                    mode = .search
                    showingScanner = false
                    Task { await lookup() }
                }
            }
            .sheet(item: $celebration) { celebration in
                MealCelebrationView(celebration: celebration)
                    .presentationDetents([.height(310)])
                    .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("FOOD LOG").font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(AppTheme.success)
                Text("Make it count.").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                Text("Scan a Lidl product or log a meal your way.").font(.subheadline).foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Image(systemName: "fork.knife")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 48, height: 48)
                .background(AppTheme.lime, in: Circle())
        }
        .padding(.top, 14)
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(CaptureMode.allCases) { option in
                Button {
                    withAnimation(.snappy(duration: 0.22)) { mode = option }
                    if option == .scan { showingScanner = true }
                } label: {
                    Label(option.title, systemImage: option.icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(mode == option ? AppTheme.ink : AppTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(mode == option ? AppTheme.surface : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder private var captureCard: some View {
        if mode == .scan {
            Button { showingScanner = true } label: {
                HStack(spacing: 16) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 54, height: 54)
                        .background(AppTheme.lime, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan the package").font(.headline).foregroundStyle(AppTheme.ink)
                        Text("Fastest way to start a verified entry.").font(.subheadline).foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "arrow.right").font(.headline.weight(.bold)).foregroundStyle(AppTheme.ink)
                }
            }
            .buttonStyle(.plain)
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24).stroke(AppTheme.stroke) }
        } else if mode == .search {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow(title: "Product lookup")
                    TextField("EAN barcode", text: $barcode)
                        .keyboardType(.numberPad)
                        .font(.title3.weight(.semibold))
                        .padding(14)
                        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    Button {
                        Task { await lookup() }
                    } label: {
                        Label(lookingUp ? "Looking up…" : "Find product", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .disabled(lookingUp || barcode.isEmpty)
                }
            }
        } else {
            SurfaceCard {
                HStack(spacing: 13) {
                    Image(systemName: "hand.tap.fill").foregroundStyle(AppTheme.success)
                    Text("Enter nutrition from the package label below.").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.ink)
                }
            }
        }
    }

    private var recentFoods: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionEyebrow(title: "Recent verified foods")
                Spacer()
                Text("Tap to reuse").font(.caption).foregroundStyle(AppTheme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(foods.prefix(12)) { food in
                        Button(food.name) { apply(food) }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 38)
                            .background(AppTheme.surface, in: Capsule())
                            .overlay { Capsule().stroke(AppTheme.stroke) }
                    }
                }
            }
        }
    }

    private var productCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionEyebrow(title: "What did you eat?")
                        Text("Food details").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    if source == .openFoodFacts {
                        Label("Catalog match", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.success)
                    }
                }
                TextField("Food name", text: $name)
                    .accessibilityIdentifier("foodName")
                    .font(.body.weight(.semibold))
                    .padding(14)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                if let message {
                    Label(message, systemImage: source == .openFoodFacts ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(source == .openFoodFacts ? AppTheme.success : AppTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var nutritionCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionEyebrow(title: "Per 100 g")
                        Text("Nutrition label").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Text("Required").font(.caption.weight(.bold)).foregroundStyle(AppTheme.muted)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    NutrientInput(title: "Calories", value: $calories, unit: "kcal", tint: AppTheme.warning)
                    NutrientInput(title: "Protein", value: $protein, unit: "g", tint: AppTheme.success)
                    NutrientInput(title: "Carbs", value: $carbs, unit: "g", tint: Color.orange)
                    NutrientInput(title: "Fat", value: $fat, unit: "g", tint: Color.purple)
                }
                Toggle(isOn: $confirmedLabel) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("I checked the package label").font(.subheadline.weight(.semibold))
                        Text("This protects your future recommendations.").font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
                .tint(AppTheme.success)
            }
        }
    }

    private var mealCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(title: "Serving")
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("How much?").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                        Text("The total you actually ate.").font(.caption).foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    TextField("g", value: $grams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title2.weight(.bold))
                        .frame(width: 92)
                    Text("g").font(.headline).foregroundStyle(AppTheme.muted)
                }
                .padding(14)
                .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Picker("Meal", selection: $kind) {
                    ForEach(MealKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("When", selection: $consumedAt, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private var scaledCalories: Double { calories * grams / 100 }

    private var extraNutritionCard: some View {
        SurfaceCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Per 100 g. Leave anything absent from your label blank. Salt is not sodium; minerals use milligrams.")
                        .font(.caption).foregroundStyle(AppTheme.muted)
                    ForEach(LabelNutrient.allCases) { nutrient in
                        HStack {
                            Text(nutrient.title).font(.subheadline.weight(.medium))
                            Spacer()
                            TextField("Unknown", text: Binding(get: { labelValues[nutrient] ?? "" }, set: { labelValues[nutrient] = $0 }))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                                .accessibilityLabel("\(nutrient.title) per 100 grams")
                                .accessibilityIdentifier("nutrient-\(nutrient.rawValue)")
                            Text(nutrient.unit).font(.caption).foregroundStyle(AppTheme.muted).frame(width: 24)
                        }
                    }
                    if !optionalNutrientsValid {
                        Text("Use non-negative label values, or leave the field blank.").font(.caption).foregroundStyle(AppTheme.warning)
                    }
                }.padding(.top, 12)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fibre & minerals").font(.headline).foregroundStyle(AppTheme.ink)
                    Text("Optional label details").font(.caption).foregroundStyle(AppTheme.muted)
                }
            }
            .tint(AppTheme.success)
        }
    }

    private func labelNumber(_ nutrient: LabelNutrient) -> Double? {
        let text = (labelValues[nutrient] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private var optionalNutrientsValid: Bool {
        LabelNutrient.allCases.allSatisfy { nutrient in
            let text = (labelValues[nutrient] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return true }
            guard let value = labelNumber(nutrient) else { return false }
            return value.isFinite && value >= 0 && value <= nutrient.maximumPer100g
        }
    }

    private func applyLabelValues(_ nutrients: Nutrients) {
        labelValues = Dictionary(uniqueKeysWithValues: LabelNutrient.allCases.map { ($0, nutrients[$0].map { String($0) } ?? "") })
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && grams.isFinite && grams > 0 && grams <= 20_000 &&
        [calories, protein, carbs, fat].allSatisfy { $0.isFinite && $0 >= 0 } &&
        calories <= 1_000 && protein + carbs + fat <= 105 && optionalNutrientsValid
    }

    private func apply(_ food: Food) {
        name = food.name
        barcode = food.barcode ?? ""
        calories = food.nutrientsPer100g.calories
        protein = food.nutrientsPer100g.protein
        carbs = food.nutrientsPer100g.carbohydrates
        fat = food.nutrientsPer100g.fat
        applyLabelValues(food.nutrientsPer100g)
        source = food.source
        confirmedLabel = true
        mode = .manual
        message = "Reusing your verified label."
    }

    private func lookup() async {
        guard !lookingUp else { return }
        lookingUp = true
        confirmedLabel = false
        defer { lookingUp = false }
        let requestedCode = barcode
        do {
            let draft = try await catalog.lookup(barcode: requestedCode)
            guard barcode == requestedCode else { return }
            name = draft.name
            calories = draft.nutrientsPer100g.calories
            protein = draft.nutrientsPer100g.protein
            carbs = draft.nutrientsPer100g.carbohydrates
            fat = draft.nutrientsPer100g.fat
            applyLabelValues(draft.nutrientsPer100g)
            source = .openFoodFacts
            message = "Catalog values imported. Compare them with the package, then confirm."
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard valid && confirmedLabel else { return }
        let before = currentMomentum
        var nutrients = Nutrients(calories: calories, protein: protein, carbohydrates: carbs, fat: fat)
        for nutrient in LabelNutrient.allCases { nutrients[nutrient] = labelNumber(nutrient) }
        let food = Food(name: name.trimmingCharacters(in: .whitespacesAndNewlines), barcode: barcode.isEmpty ? nil : barcode,
                        nutrientsPer100g: nutrients, source: source)
        food.labelConfirmed = true
        context.insert(food)
        context.insert(MealEntry(food: food, grams: grams, kind: kind, consumedAt: consumedAt))
        do {
            try context.save()
            let meals = entries.filter { Calendar.current.isDate($0.consumedAt, inSameDayAs: consumedAt) }
            let portion = nutrients.scaled(by: grams / 100)
            let after = MomentumEngine.snapshot(for: MomentumDay(date: consumedAt, mealCount: meals.count + 1, protein: meals.reduce(0) { $0 + $1.nutrients.protein } + portion.protein, reviewed: false), history: [], proteinTarget: goals.first?.proteinTarget ?? 140, calendar: .current)
            celebration = MealCelebration(points: max(10, after.points - before.points), calories: scaledCalories, protein: portion.protein)
            message = "Logged \(Int(scaledCalories)) kcal for \(consumedAt.formatted(date: .abbreviated, time: .shortened))."
            name = ""
            barcode = ""
            grams = 100
            calories = 0
            protein = 0
            carbs = 0
            fat = 0
            labelValues = [:]
            confirmedLabel = false
            source = .manual
        } catch {
            context.rollback()
            message = "Could not save meal: \(error.localizedDescription)"
        }
    }

    private var currentMomentum: MomentumSnapshot {
        let meals = entries.filter { Calendar.current.isDate($0.consumedAt, inSameDayAs: consumedAt) }
        return MomentumEngine.snapshot(for: MomentumDay(date: consumedAt, mealCount: meals.count, protein: meals.reduce(0) { $0 + $1.nutrients.protein }, reviewed: false), history: [], proteinTarget: goals.first?.proteinTarget ?? 140, calendar: .current)
    }
}

private struct MealCelebration: Identifiable {
    let id = UUID()
    let points: Int
    let calories: Double
    let protein: Double
}

private struct MealCelebrationView: View {
    let celebration: MealCelebration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 78, height: 78)
                .background(AppTheme.lime, in: Circle())
            Text("Logged. Keep moving.").font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
            Text("+\(celebration.points) momentum · \(Int(celebration.calories)) kcal · \(Int(celebration.protein)) g protein")
                .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.muted)
            Button("Back to your day") { dismiss() }.buttonStyle(PrimaryActionStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.canvas)
    }
}

private struct NutrientInput: View {
    let title: String
    @Binding var value: Double
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(title).font(.caption.weight(.bold)).foregroundStyle(AppTheme.muted)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                TextField("0", value: $value, format: .number)
                    .accessibilityIdentifier("macro-\(title.lowercased())")
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
                Text(unit).font(.caption.weight(.bold)).foregroundStyle(AppTheme.muted)
            }
        }
        .padding(13)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
