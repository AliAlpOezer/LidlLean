import SwiftData
import SwiftUI

struct ShoppingListBuilder: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.verifiedAt, order: .reverse) private var foods: [Food]
    @Query private var basket: [ShoppingItem]
    @AppStorage("plannerAvoid") private var avoid = ""
    @State private var selectedFoodID: UUID?
    @State private var manual = false
    @State private var name = ""
    @State private var grams = 150.0
    @State private var days = 3
    @State private var shoppingDate = Date.now
    @State private var errorMessage: String?

    private var savedFoods: [Food] {
        let excluded = avoid.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var seen = Set<String>()
        return foods.filter { food in
            food.labelConfirmed && !excluded.contains { food.name.localizedCaseInsensitiveContains($0) }
                && seen.insert(food.name.lowercased()).inserted
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var selectedFood: Food? { savedFoods.first { $0.id == selectedFoodID } }
    private var itemName: String { manual ? name.trimmingCharacters(in: .whitespacesAndNewlines) : selectedFood?.name ?? "" }
    private var totalGrams: Double { grams * Double(days) }
    private var valid: Bool { !itemName.isEmpty && grams.isFinite && grams > 0 && totalGrams <= 20_000 }
    private var identifier: String {
        let source = manual ? itemName.lowercased() : selectedFoodID?.uuidString ?? ""
        return "staple:\(source):\(Calendar.current.startOfDay(for: shoppingDate).timeIntervalSince1970)"
    }
    private var alreadyAdded: Bool { basket.contains { $0.offerID == identifier } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("A few staples. Fewer decisions.").font(.title2.bold())
                    Text("Choose a food, a daily portion, and how many days to cover. Your list does the arithmetic.")
                        .foregroundStyle(AppTheme.muted)
                }
                Section("Choose a staple") {
                    Toggle("Add something new", isOn: $manual)
                    if manual {
                        TextField("Shopping item name", text: $name).accessibilityIdentifier("shoppingItemName")
                        Text("Nutrition and price stay unknown. You can attach a checked label later.").font(.caption)
                    } else if savedFoods.isEmpty {
                        Text("Your checked food labels will appear here after you log them. Add something new to start your list now.")
                            .foregroundStyle(AppTheme.muted)
                    } else {
                        Picker("Saved food", selection: $selectedFoodID) {
                            Text("Choose a food").tag(Optional<UUID>.none)
                            ForEach(savedFoods) { food in Text(food.name).tag(Optional(food.id)) }
                        }
                        Text("Uses your checked labels and name exclusions. Always check ingredients for allergens.").font(.caption)
                    }
                }
                Section("Plan the amount") {
                    HStack {
                        Text("Daily portion")
                        Spacer()
                        TextField("Grams", value: $grams, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("shoppingPortion")
                        Text("g").foregroundStyle(AppTheme.muted)
                    }
                    Stepper("Cover \(days) day\(days == 1 ? "" : "s")", value: $days, in: 1...14)
                    DatePicker("Shop on", selection: $shoppingDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                }
                if valid {
                    Section("Your list will include") {
                        LabeledContent(itemName, value: "\(totalGrams.formatted(.number.precision(.fractionLength(0...1)))) g")
                            .font(.headline)
                        Text("\(grams.formatted()) g × \(days) days. Check pack sizes in store.")
                            .font(.caption).foregroundStyle(AppTheme.muted)
                        if let food = selectedFood, !manual {
                            let nutrients = food.nutrientsPer100g.scaled(by: totalGrams / 100)
                            Text("\(Int(nutrients.calories)) kcal · \(Int(nutrients.protein)) g protein across this amount")
                                .font(.subheadline)
                        }
                        Text("Price and store availability unconfirmed.").font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(AppTheme.warning) }
            }
            .tint(AppTheme.success)
            .navigationTitle("Plan a shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(alreadyAdded ? "On your list" : "Add to list", action: add)
                        .disabled(!valid || alreadyAdded).accessibilityIdentifier("addStaple")
                }
            }
        }
    }

    private func add() {
        guard valid, !alreadyAdded else { return }
        let item = ShoppingItem(offerID: identifier, name: itemName, unitPrice: 0,
                                productURL: nil, imageURL: nil, plannedFor: shoppingDate)
        item.priceKnown = false
        item.plannedGrams = totalGrams
        item.coverageDays = days
        if let food = selectedFood, !manual {
            item.nutritionConfirmed = true
            item.caloriesPer100g = food.nutrientsPer100g.calories
            item.proteinPer100g = food.nutrientsPer100g.protein
        }
        context.insert(item)
        do { try context.save(); dismiss() }
        catch { context.rollback(); errorMessage = "Could not save your list: \(error.localizedDescription)" }
    }
}
