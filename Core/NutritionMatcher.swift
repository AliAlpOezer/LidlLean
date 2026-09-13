import Foundation

enum NutritionMatcher {
    static func estimate(for title: String, knownFoods: [Food]) -> Nutrients? {
        knownFoods.first {
            $0.labelConfirmed && $0.name.caseInsensitiveCompare(title) == .orderedSame
        }?.nutrientsPer100g
    }

    static func looksLikeFood(_ offer: LidlOffer) -> Bool {
        let category = normalize(offer.category ?? "")
        return ["lebensmittel", "essen & trinken", "essen trinken", "molkereiprodukte", "obst", "gemuse", "fleisch", "fisch"].contains(where: category.contains)
    }

    private static func normalize(_ value: String) -> String { value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE")).lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression) }
}
