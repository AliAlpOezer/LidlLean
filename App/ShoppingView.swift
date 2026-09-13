import SwiftData
import SwiftUI

struct ShoppingView: View {
    @Query private var foods: [Food]
    @State private var flyers: [LidlFlyer] = []
    @State private var flyerError: String?
    private let flyerClient = LidlFlyerClient()
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
                    if flyers.isEmpty, flyerError == nil {
                        Text("Fetching the current official flyer...").foregroundStyle(AppTheme.muted)
                    }
                    ForEach(flyers) { flyer in
                        LabeledContent(flyer.title, value: flyer.validity)
                    }
                    if let flyerError {
                        Text(flyerError).font(.footnote).foregroundStyle(AppTheme.muted)
                    }
                    Link("Open official Lidl flyer", destination: LidlFlyerClient.officialProspectURL)
                        .fontWeight(.semibold)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.canvas)
            .navigationTitle("Shopping plan")
            .task { await loadFlyers() }
        }
    }

    private func loadFlyers() async {
        do { flyers = try await flyerClient.currentFlyers(); flyerError = flyers.isEmpty ? "Lidl did not expose flyer dates in the page response. Open the official flyer." : nil }
        catch { flyerError = "Could not load Lidl offers. Check your connection and try again." }
    }
}
