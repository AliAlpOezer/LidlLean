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
                shopHeader
                sectionSwitcher
                Group {
                    if selection == 0 { offersView }
                    else if selection == 1 { flyerView }
                    else { basketView }
                }
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await load() }
        }
    }

    private var shopHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("LIDL WEEK").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(AppTheme.primary)
                Text("Shop smarter").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                Text(catalog.map { "\($0.offers.count) live offers · valid through \($0.validUntil.formatted(.dateTime.month(.abbreviated).day()))" } ?? "Your protein-first basket, in one place")
                    .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted).lineLimit(2)
            }
            Spacer(minLength: 8)
            Button { Task { await load(force: true) } } label: {
                Image(systemName: refreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.lime, in: Circle())
            }
            .disabled(refreshing)
            .accessibilityLabel("Refresh Lidl offers")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var sectionSwitcher: some View {
        HStack(spacing: 4) {
            shopSegment("Offers", systemImage: "tag.fill", index: 0)
            shopSegment("Flyer", systemImage: "doc.text.image", index: 1)
            shopSegment("Basket", systemImage: "basket.fill", index: 2, badge: basket.count)
        }
        .padding(4)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func shopSegment(_ title: String, systemImage: String, index: Int, badge: Int? = nil) -> some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { selection = index } } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
                if let badge, badge > 0 { Text("\(badge)").font(.caption2.weight(.bold)).padding(.horizontal, 5).padding(.vertical, 2).background(AppTheme.lime, in: Capsule()) }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(selection == index ? AppTheme.ink : AppTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(selection == index ? AppTheme.surface : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var offersView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                catalogHeader
                HStack {
                    Label("Food only", systemImage: "fork.knife")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    Spacer()
                    Toggle("Food only", isOn: $foodOnly).labelsHidden().tint(AppTheme.success)
                    Text("\(visibleOffers.count)").font(.caption.weight(.bold)).foregroundStyle(AppTheme.primary)
                }.padding(.horizontal)
                ForEach(visibleOffers) { offer in
                    OfferCard(offer: offer, alreadyAdded: basket.contains(where: { $0.offerID == offer.id }), knownFood: foods.first(where: { $0.name.caseInsensitiveCompare(offer.title) == .orderedSame })) { add(offer) }
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
                    HStack {
                        Label(catalog.validUntil >= Date.now ? "Live Lidl offers" : "Expired Lidl offers", systemImage: catalog.validUntil >= Date.now ? "circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(catalog.validUntil >= .now ? AppTheme.success : AppTheme.warning)
                        Spacer()
                        Text(catalog.fetchedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2.weight(.medium)).foregroundStyle(AppTheme.muted)
                    }
                    Text(catalog.title).font(.title2.bold()).foregroundStyle(AppTheme.ink)
                    Text("\(catalog.offers.count) offers · \(catalog.pages.count) full-page scans")
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                    if catalog.validUntil < Date.now {
                        Text("This flyer has expired. Refresh before using prices.").font(.caption).foregroundStyle(AppTheme.warning)
                    }
                }
            }.padding(.horizontal)
        } else if let errorMessage {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Lidl connection failed", systemImage: "wifi.exclamationmark")
                        .font(.headline.weight(.bold)).foregroundStyle(AppTheme.warning)
                    Text(errorMessage).font(.subheadline).foregroundStyle(AppTheme.muted)
                    HStack(spacing: 12) {
                        Button("Try again", systemImage: "arrow.clockwise") { Task { await load(force: true) } }
                            .buttonStyle(.borderedProminent).tint(AppTheme.primary)
                        Link("Open Lidl.de", destination: LidlCatalogClient.officialProspectURL)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .padding(.horizontal)
        } else {
            SurfaceCard {
                HStack(spacing: 12) {
                    ProgressView().tint(AppTheme.primary)
                    Text("Fetching this week's Lidl offers…").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
                }
            }.padding(.horizontal)
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
    let knownFood: Food?
    let add: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: offer.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ZStack {
                    AppTheme.elevated
                    Image(systemName: "cart.fill").foregroundStyle(AppTheme.primary.opacity(0.55))
                }
            }
            .frame(width: 86, height: 86)
            .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                if let brand = offer.brand { Text(brand.uppercased()).font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(AppTheme.muted) }
                Text(offer.title).font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink).lineLimit(3)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(offer.price.formatted(.currency(code: "EUR"))).font(.title3.weight(.bold)).foregroundStyle(AppTheme.primary)
                    if let food = knownFood { Text("\(Int(food.nutrientsPer100g.protein))g protein/100g").font(.caption).foregroundStyle(AppTheme.success) }
                }
            }
            Spacer(minLength: 2)
            Button(action: add) {
                Image(systemName: alreadyAdded ? "checkmark" : "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(alreadyAdded ? AppTheme.success : AppTheme.ink)
                    .frame(width: 42, height: 42)
                    .background(alreadyAdded ? AppTheme.success.opacity(0.13) : AppTheme.lime, in: Circle())
            }
            .disabled(alreadyAdded)
            .accessibilityLabel(alreadyAdded ? "Added to basket" : "Add \(offer.title) to basket")
        }
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.ink.opacity(0.055)) }
        .shadow(color: AppTheme.ink.opacity(0.045), radius: 12, y: 6)
        .padding(.horizontal, 16)
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
