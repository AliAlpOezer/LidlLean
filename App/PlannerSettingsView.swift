import SwiftData
import SwiftUI

struct PlannerSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [UserGoal]
    @AppStorage("plannerConfigured") private var configured = false
    @AppStorage("plannerAvoid") private var storedAvoid = ""
    @AppStorage("weeklyWeightLossGoal") private var storedWeightGoal = 1.0
    @State private var weightGoal = 1.0
    @State private var weeklyCalories = 0.0
    @State private var dailyProtein = 0.0
    @State private var avoid = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your chosen targets") {
                    LabeledContent("Weekly loss goal (kg)") { TextField("kg", value: $weightGoal, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Weekly calories") { TextField("kcal", value: $weeklyCalories, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Daily protein") { TextField("g", value: $dailyProtein, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Text("Weekly calories ÷ 7 sets the daily intake target. Expenditure is displayed separately and does not automatically increase your food budget.")
                }
                Section("Recommendation preferences") {
                    TextField("Avoid these name fragments, separated by commas", text: $avoid)
                    Text("This filters product names only; check the ingredient label for allergens.").font(.caption)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                Button("Save goals") { save() }.disabled(!valid)
            }
            .navigationTitle("Weekly goal")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear {
                weeklyCalories = configured ? (goals.first?.calorieTarget ?? 0) * 7 : 0
                dailyProtein = configured ? goals.first?.proteinTarget ?? 0 : 0
                avoid = storedAvoid
                weightGoal = storedWeightGoal
            }
        }
    }

    private var valid: Bool {
        weightGoal.isFinite && weightGoal >= 0 && weightGoal <= 2 && weeklyCalories.isFinite && dailyProtein.isFinite && weeklyCalories > 0 && weeklyCalories <= 70000 && dailyProtein > 0 && dailyProtein <= 500
    }
    private func save() {
        guard valid else { return }
        let goal = goals.first ?? UserGoal()
        if goals.isEmpty { context.insert(goal) }
        goal.calorieTarget = weeklyCalories / 7
        goal.proteinTarget = dailyProtein
        do {
            try context.save()
            storedAvoid = avoid
            storedWeightGoal = weightGoal
            configured = true
            dismiss()
        } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}
