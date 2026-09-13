import SwiftData
import SwiftUI

struct LidlShoppingView: View {
    @Environment(\.modelContext) private var context
    @Query private var foods: [Food]
    @Query(sort: \ShoppingItem.addedAt) private var basket: [ShoppingItem]
    @State private var catalog: LidlWeeklyCatalog?
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var foodOnly = true
    @State private var selection = 0
    @State private var flyerPage = 0
    @State private var refreshing = false
    private let client = LidlCatalogClient()

    private var visibleOffers: [LidlOffer] {
        guard let catalog else { return [] }
        return catalog.offers.filter { offer in
            (!foodOnly || NutritionMatcher.looksLikeFood(offer)) &&
            (search.isEmpty || offer.title.localizedCaseInsensitiveContains(search) || offer.brand?.localizedCaseInsensitiveContains(search) == true)
        }
    }
    private var totalPrice: Double { basket.filter(\.priceKnown).reduce(0) { $0 + $1.unitPrice * Double($1.quantity) } }
    private var totalCalories: Double { basket.filter(\.nutritionConfirmed).reduce(0) { $0 + ($1.caloriesPer100g ?? 0) * $1.plannedGrams / 100 } }
    private var totalProtein: Double { basket.filter(\.nutritionConfirmed).reduce(0) { $0 + ($1.proteinPer100g ?? 0) * $1.plannedGrams / 100 } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Shopping section", selection: $selection) {
                    Text("Offers").tag(0)
                    Text("Flyer").tag(1)
                    Text("My basket").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                Group {
                    if selection == 0 { offersView }
                    else if selection == 1 { flyerView }
                    else { basketView }
                }
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("Lidl week")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await load(force: true) } } label: { Image(systemName: "arrow.clockwise") }.disabled(refreshing) } }
            .task { await load() }
        }
    }

    private var offersView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                catalogHeader
                HStack {
                    Toggle("Food only", isOn: $foodOnly).tint(AppTheme.lime)
                    Text("\(visibleOffers.count) offers").font(.caption).foregroundStyle(AppTheme.muted)
                }.padding(.horizontal)
                ForEach(visibleOffers) { offer in
                    OfferCard(offer: offer, alreadyAdded: basket.contains(where: { $0.offerID == offer.id })) { add(offer) }
                }
                if visibleOffers.isEmpty, catalog != nil {
                    ContentUnavailableView("No matching structured offers", systemImage: "cart", description: Text("Switch off Food only to browse every product, or view the complete flyer pages."))
                }
            }.padding(.bottom, 20)
        }.searchable(text: $search, prompt: "Search this week's offers")
    }

    @ViewBuilder private var catalogHeader: some View {
        if let catalog {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 7) {
                    SectionEyebrow(title: "Live Lidl catalog")
                    Text(catalog.title).font(.title2.bold()).foregroundStyle(AppTheme.ink)
                    Text("\(catalog.offers.count) structured offers · \(catalog.pages.count) flyer pages").font(.subheadline).foregroundStyle(AppTheme.muted)
                    Text("Fetched \(catalog.fetchedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(AppTheme.muted)
                    if catalog.validUntil < Date.now { Text("Expired flyer. Refresh before relying on these prices.").foregroundStyle(.orange) }
                    if Date.now.timeIntervalSince(catalog.fetchedAt) > 6 * 60 * 60 { Text("Showing saved data; live refresh was unavailable.").foregroundStyle(.orange) }
                }
            }.padding(.horizontal)
        } else if let errorMessage {
            ContentUnavailableView("Lidl data unavailable", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
        } else {
            ProgressView("Fetching Lidl's current catalog...").tint(AppTheme.lime).padding(40)
        }
    }

    private var flyerView: some View {
        ScrollView {
            VStack(spacing: 16) {
                catalogHeader
                if let catalog {
                    if !catalog.pages.isEmpty {
                        HStack {
                            Button { flyerPage = max(flyerPage - 1, 0) } label: {
                                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                            }.disabled(flyerPage == 0)
                            Spacer()
                            Text("Page \(flyerPage + 1) of \(catalog.pages.count)").font(.subheadline.weight(.semibold))
                            Spacer()
                            Button { flyerPage = min(flyerPage + 1, catalog.pages.count - 1) } label: {
                                Image(systemName: "chevron.right").frame(width: 44, height: 44)
                            }.disabled(flyerPage == catalog.pages.count - 1)
                        }
                        .padding(.horizontal)
                        TabView(selection: $flyerPage) {
                            ForEach(Array(catalog.pages.enumerated()), id: \.element.id) { index, page in
                                AsyncImage(url: page.imageURL) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 18).fill(AppTheme.surface)
                                        .overlay { ProgressView() }
                                }
                                .padding(.horizontal)
                                .tag(index)
                            }
                        }
                        .frame(height: 500)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                    Link("Open complete flyer on Lidl.de", destination: catalog.flyerURL)
                        .font(.headline).foregroundStyle(AppTheme.primary).frame(minHeight: 44)
                }
            }.padding(.bottom, 24)
        }
    }

    private var basketView: some View {
        List {
            Section {
                LabeledContent("Known price subtotal", value: totalPrice.formatted(.currency(code: "EUR")))
                LabeledContent("Confirmed calorie subtotal", value: "\(Int(totalCalories)) kcal")
                LabeledContent("Confirmed protein subtotal", value: "\(Int(totalProtein)) g")
                Text("\(basket.filter { !$0.priceKnown }.count) items lack a price; \(basket.filter { !$0.nutritionConfirmed }.count) need a nutrition label. These are excluded from subtotals.").font(.caption)
            } header: { Text("PLAN TOTAL") }
            Section("ITEMS") {
                if basket.isEmpty { Text("Add Lidl offers to build your week.").foregroundStyle(AppTheme.muted) }
                ForEach(basket) { item in BasketRow(item: item) }
                    .onDelete { indexes in indexes.map { basket[$0] }.forEach(context.delete) }
            }
        }.scrollContentBackground(.hidden).background(AppTheme.canvas)
    }

    private func load(force: Bool = false) async {
        refreshing = true
        defer { refreshing = false }
        do { catalog = try await client.weeklyCatalog(forceRefresh: force); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    private func add(_ offer: LidlOffer) {
        guard !basket.contains(where: { $0.offerID == offer.id }) else { return }
        let item = ShoppingItem(offerID: offer.id, name: offer.title, unitPrice: offer.price, productURL: offer.productURL?.absoluteString, imageURL: offer.imageURL?.absoluteString)
        if let estimate = NutritionMatcher.estimate(for: offer.title, knownFoods: foods) {
            item.caloriesPer100g = estimate.calories
            item.proteinPer100g = estimate.protein
            item.nutritionConfirmed = true
        }
        context.insert(item)
        do { try context.save() } catch { context.rollback(); errorMessage = "Could not save shopping item: \(error.localizedDescription)" }
    }
}

private struct OfferCard: View {
    let offer: LidlOffer
    let alreadyAdded: Bool
    let add: () -> Void
    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    AsyncImage(url: offer.imageURL) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: "photo").foregroundStyle(AppTheme.muted) }
                        .frame(width: 84, height: 84).background(.white, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 6) {
                        if let brand = offer.brand { Text(brand.uppercased()).font(.caption2.bold()).foregroundStyle(AppTheme.muted) }
                        Text(offer.title).font(.headline).foregroundStyle(AppTheme.ink).lineLimit(3)
                        Text(offer.price.formatted(.currency(code: "EUR"))).font(.title3.bold()).foregroundStyle(AppTheme.primary)
                    }
                }
                Button(action: add) {
                    Label(alreadyAdded ? "Added to basket" : "Add to basket", systemImage: alreadyAdded ? "checkmark" : "plus")
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(alreadyAdded)
            }
        }.padding(.horizontal)
    }
}

private struct BasketRow: View {
    @Bindable var item: ShoppingItem
    @Query private var foods: [Food]
    private var nutrition: String {
        guard item.nutritionConfirmed, let calories = item.caloriesPer100g else { return "Nutrition needs confirmation" }
        return "\(Int(calories * item.plannedGrams / 100)) kcal · \(Int((item.proteinPer100g ?? 0) * item.plannedGrams / 100))g protein"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(item.name).fontWeight(.semibold); Spacer(); Text(item.priceKnown ? (item.unitPrice * Double(item.quantity)).formatted(.currency(code: "EUR")) : "Price unknown").foregroundStyle(AppTheme.lime) }
            Text(nutrition).font(.caption).foregroundStyle(AppTheme.muted)
            Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...20)
            Stepper("Total planned amount: \(Int(item.plannedGrams)) g", value: $item.plannedGrams, in: 0...20000, step: 25)
            Text("Planned grams cover the whole line, independently of pack quantity.").font(.caption)
            Menu("Use a checked food label") {
                ForEach(foods.filter(\.labelConfirmed)) { food in
                    Button(food.name) {
                        item.caloriesPer100g = food.nutrientsPer100g.calories
                        item.proteinPer100g = food.nutrientsPer100g.protein
                        item.nutritionConfirmed = true
                    }
                }
            }
        }
    }
}
