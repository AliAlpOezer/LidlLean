import SwiftData
import SwiftUI

struct ShoppingView: View {
    @Query private var foods: [Food]
    private var picks: [Food] { foods.filter { $0.nutrientsPer100g.calories > 0 }.sorted { $0.nutrientsPer100g.protein / $0.nutrientsPer100g.calories > $1.nutrientsPer100g.protein / $1.nutrientsPer100g.calories }.prefix(10).map { $0 } }
    var body: some View {
        NavigationStack {
            List {
                Section("YOUR HIGH-PROTEIN PICKS") {
                    if picks.isEmpty {
                        Text("Log foods first. Your best protein-per-calorie options will appear here.")
                            .foregroundStyle(AppTheme.muted)
                    }
                    ForEach(picks) { food in
                        LabeledContent(food.name, value: "\(Int(food.nutrientsPer100g.protein))g protein · \(Int(food.nutrientsPer100g.calories)) kcal")
                    }
                }
                Section("LIDL OFFERS") {
                    Text("Offer integration is held until we have a permitted, dependable source. Lidl Plus credentials are never accessed.")
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.canvas)
            .navigationTitle("Shopping plan")
        }
    }
}
