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
    @State private var refreshing = false
    private let client = LidlCatalogClient()

    private var visibleOffers: [LidlOffer] {
        guard let catalog else { return [] }
        return catalog.offers.filter { offer in
            (!foodOnly || NutritionMatcher.looksLikeFood(offer)) &&
            (search.isEmpty || offer.title.localizedCaseInsensitiveContains(search) || offer.brand?.localizedCaseInsensitiveContains(search) == true)
        }
    }
    private var totalPrice: Double { basket.reduce(0) { $0 + $1.unitPrice * Double($1.quantity) } }
    private var totalCalories: Double { basket.reduce(0) { $0 + ($1.caloriesPer100g ?? 0) * $1.plannedGrams / 100 } }
    private var totalProtein: Double { basket.reduce(0) { $0 + ($1.proteinPer100g ?? 0) * $1.plannedGrams / 100 } }

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
                    Text("LIVE FROM LIDL.DE").font(.caption.weight(.black)).tracking(1.4).foregroundStyle(AppTheme.lime)
                    Text(catalog.title).font(.title2.bold()).foregroundStyle(AppTheme.ink)
                    Text("\(catalog.offers.count) structured offers · \(catalog.pages.count) flyer pages").font(.subheadline).foregroundStyle(AppTheme.muted)
                    Text("Updated \(catalog.fetchedAt.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(AppTheme.muted)
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
            LazyVStack(spacing: 18) {
                catalogHeader
                if let catalog {
                    ForEach(catalog.pages) { page in
                        AsyncImage(url: page.imageURL) { image in image.resizable().scaledToFit() } placeholder: {
                            RoundedRectangle(cornerRadius: 18).fill(AppTheme.surface).frame(height: 420).overlay { ProgressView() }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(alignment: .topLeading) { Text("PAGE \(page.number)").font(.caption.bold()).padding(8).background(.black.opacity(0.72), in: Capsule()).padding(10) }
                        .padding(.horizontal)
                    }
                    Link("Open interactive flyer on Lidl.de", destination: catalog.flyerURL).foregroundStyle(AppTheme.lime).fontWeight(.bold)
                }
            }.padding(.bottom, 24)
        }
    }

    private var basketView: some View {
        List {
            Section {
                LabeledContent("Estimated checkout", value: totalPrice.formatted(.currency(code: "EUR")))
                LabeledContent("Planned calories", value: "\(Int(totalCalories)) kcal")
                LabeledContent("Planned protein", value: "\(Int(totalProtein)) g")
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
        }
        context.insert(item)
    }
}

private struct OfferCard: View {
    let offer: LidlOffer
    let alreadyAdded: Bool
    let add: () -> Void
    var body: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                AsyncImage(url: offer.imageURL) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: "photo").foregroundStyle(AppTheme.muted) }
                    .frame(width: 88, height: 88).background(.white, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 6) {
                    if let brand = offer.brand { Text(brand.uppercased()).font(.caption2.bold()).foregroundStyle(AppTheme.muted) }
                    Text(offer.title).font(.headline).foregroundStyle(AppTheme.ink).lineLimit(3)
                    Text(offer.price.formatted(.currency(code: "EUR"))).font(.title3.bold()).foregroundStyle(AppTheme.lime)
                }
                Spacer()
                Button(action: add) { Image(systemName: alreadyAdded ? "checkmark" : "plus").font(.headline).frame(width: 34, height: 34).background(alreadyAdded ? AppTheme.elevated : AppTheme.lime, in: Circle()).foregroundStyle(alreadyAdded ? AppTheme.lime : AppTheme.canvas) }.disabled(alreadyAdded)
            }
        }.padding(.horizontal)
    }
}

private struct BasketRow: View {
    @Bindable var item: ShoppingItem
    private var nutrition: String {
        guard let calories = item.caloriesPer100g else { return "Nutrition needs confirmation" }
        return "\(Int(calories * item.plannedGrams / 100)) kcal · \(Int((item.proteinPer100g ?? 0) * item.plannedGrams / 100))g protein"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(item.name).fontWeight(.semibold); Spacer(); Text((item.unitPrice * Double(item.quantity)).formatted(.currency(code: "EUR"))).foregroundStyle(AppTheme.lime) }
            Text(nutrition).font(.caption).foregroundStyle(AppTheme.muted)
            Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...20)
            HStack { Text("Planned grams"); TextField("Grams", value: $item.plannedGrams, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90) }
        }
    }
}
