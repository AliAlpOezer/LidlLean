import Foundation

enum NutritionMatcher {
    static func estimate(for title: String, knownFoods: [Food]) -> Nutrients? {
        knownFoods.first {
            $0.labelConfirmed && $0.name.caseInsensitiveCompare(title) == .orderedSame
        }?.nutrientsPer100g
    }

    static func looksLikeFood(_ offer: LidlOffer) -> Bool {
        let value = normalize([offer.category, offer.title, offer.brand].compactMap { $0 }.joined(separator: " "))
        let nonFood = ["werkzeug", "textil", "kleidung", "schuhe", "garten", "elektro", "haushalt", "spielzeug", "deko"]
        guard !nonFood.contains(where: value.contains) else { return false }
        let food = ["lebensmittel", "essen", "trinken", "molkerei", "obst", "gemuse", "fleisch", "fisch", "back", "tiefkuhl", "getrank", "protein", "skyr", "quark", "joghurt", "kase", "milch", "tofu", "hahnchen", "rind", "lachs", "garnelen", "ei", "kartoffel", "reis", "nudel", "brot", "hafer", "salat", "pizza", "wasser", "kaffee", "tee"]
        return food.contains(where: value.contains)
    }

    private static func normalize(_ value: String) -> String { value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE")).lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression) }
}
