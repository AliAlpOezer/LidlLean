import SwiftData
import SwiftUI

struct AddFoodView: View {
    @Environment(\.modelContext) private var context
    @State private var name = ""; @State private var barcode = ""; @State private var grams = 100.0; @State private var calories = 0.0; @State private var protein = 0.0; @State private var carbs = 0.0; @State private var fat = 0.0; @State private var kind: MealKind = .snack; @State private var message: String?; @State private var showingScanner = false
    private let catalog = OpenFoodFactsClient()
    @Query(sort: \Food.verifiedAt, order: .reverse) private var foods: [Food]
    @State private var consumedAt = Date.now
    @State private var source: FoodSource = .manual
    @State private var lookingUp = false
    @State private var confirmedLabel = false

    var body: some View {
        NavigationStack {
            Form {
                if !foods.isEmpty {
                    Section("Reuse a saved food") {
                        Menu("Choose food") {
                            ForEach(foods.prefix(40)) { food in
                                Button(food.name) {
                                    name = food.name; barcode = food.barcode ?? ""
                                    calories = food.nutrientsPer100g.calories; protein = food.nutrientsPer100g.protein
                                    carbs = food.nutrientsPer100g.carbohydrates; fat = food.nutrientsPer100g.fat
                                    source = food.source; confirmedLabel = false
                                }
                            }
                        }
                    }
                }
                Section("Product") {
                    TextField("Name", text: $name)
                    TextField("EAN barcode", text: $barcode).keyboardType(.numberPad)
                    Button("Scan barcode", systemImage: "barcode.viewfinder") { showingScanner = true }
                    Button("Look up product") { Task { await lookup() } }.disabled(lookingUp || barcode.isEmpty)
                    if let message { Text(message).font(.footnote).foregroundStyle(AppTheme.muted) }
                }
                Section("Per 100 g") {
                    number("Calories", $calories, "kcal")
                    number("Protein", $protein, "g")
                    number("Carbohydrates", $carbs, "g")
                    number("Fat", $fat, "g")
                    Toggle("I checked these nutrition values", isOn: $confirmedLabel)
                }
                Section("Meal") {
                    DatePicker("When eaten", selection: $consumedAt, in: ...Date.now)
                    number("Amount", $grams, "g")
                    Picker("Meal", selection: $kind) { ForEach(MealKind.allCases) { Text($0.title).tag($0) } }
                    Button("Log meal") { save() }.disabled(!valid || !confirmedLabel || lookingUp)
                }
            }
            .scrollContentBackground(.hidden).background(AppTheme.canvas).navigationTitle("Log food")
            .sheet(isPresented: $showingScanner) {
                BarcodeScanner { barcode = $0; showingScanner = false; Task { await lookup() } }
            }
        }
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && grams.isFinite && grams > 0 && grams <= 20000 &&
        [calories, protein, carbs, fat].allSatisfy { $0.isFinite && $0 >= 0 } &&
        calories <= 1000 && protein + carbs + fat <= 105
    }
    private func number(_ title: String, _ value: Binding<Double>, _ suffix: String) -> some View {
        LabeledContent("\(title) (\(suffix))") {
            TextField(title, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
    }
    private func lookup() async {
        guard !lookingUp else { return }
        lookingUp = true; confirmedLabel = false
        defer { lookingUp = false }
        let requestedCode = barcode
        do {
            let draft = try await catalog.lookup(barcode: requestedCode)
            guard barcode == requestedCode else { return }
            name = draft.name; calories = draft.nutrientsPer100g.calories; protein = draft.nutrientsPer100g.protein
            carbs = draft.nutrientsPer100g.carbohydrates; fat = draft.nutrientsPer100g.fat
            source = .openFoodFacts
            message = "Imported from Open Food Facts. Check the package label."
        } catch { message = error.localizedDescription }
    }
    private func save() {
        guard valid && confirmedLabel else { return }
        let nutrients = Nutrients(calories: calories, protein: protein, carbohydrates: carbs, fat: fat)
        let food = Food(name: name.trimmingCharacters(in: .whitespacesAndNewlines), barcode: barcode.isEmpty ? nil : barcode,
                        nutrientsPer100g: nutrients, source: source)
        food.labelConfirmed = true
        context.insert(food)
        context.insert(MealEntry(food: food, grams: grams, kind: kind, consumedAt: consumedAt))
        do {
            try context.save()
            message = "Meal saved for \(consumedAt.formatted(date: .abbreviated, time: .shortened))."
            name = ""; barcode = ""; grams = 100; calories = 0; protein = 0; carbs = 0; fat = 0
            confirmedLabel = false; source = .manual
        } catch { context.rollback(); message = "Could not save meal: \(error.localizedDescription)" }
    }
}
