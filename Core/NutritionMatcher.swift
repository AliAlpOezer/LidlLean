import Foundation

enum NutritionMatcher {
    static func estimate(for title: String, knownFoods: [Food]) -> Nutrients? {
        let query = tokens(title)
        if let match = knownFoods.map({ ($0, score(query, tokens($0.name))) }).filter({ $0.1 >= 0.5 }).max(by: { $0.1 < $1.1 })?.0 { return match.nutrientsPer100g }
        let normalized = normalize(title)
        return references.first(where: { entry in entry.aliases.contains(where: normalized.contains) })?.nutrients
    }

    static func looksLikeFood(_ offer: LidlOffer) -> Bool {
        let text = normalize([offer.title, offer.category ?? ""].joined(separator: " "))
        return foodWords.contains(where: text.contains)
    }

    private static func score(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(min(lhs.count, rhs.count))
    }
    private static func tokens(_ value: String) -> Set<String> { Set(normalize(value).split(separator: " ").map(String.init).filter { $0.count > 2 && !stopWords.contains($0) }) }
    private static func normalize(_ value: String) -> String { value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE")).lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression) }

    private static let stopWords: Set<String> = ["der", "die", "das", "mit", "und", "oder", "von", "fur", "set", "pack"]
    private static let foodWords = ["lebensmittel", "essen", "trinken", "obst", "gemuse", "fleisch", "fisch", "molk", "kase", "joghurt", "quark", "skyr", "protein", "brot", "back", "snack", "schokolade", "kaffee", "bier", "wein", "spirituosen", "saft", "getrank", "orange", "apfel", "banane", "tomate", "gurke", "hahnchen", "lachs", "thunfisch"]
    private static let references: [(aliases: [String], nutrients: Nutrients)] = [
        (["hahnchenbrust", "hahnchen filet"], Nutrients(calories: 110, protein: 23, carbohydrates: 0, fat: 1.5)),
        (["magerquark"], Nutrients(calories: 67, protein: 12, carbohydrates: 4, fat: 0.3)),
        (["skyr"], Nutrients(calories: 64, protein: 11, carbohydrates: 4, fat: 0.2)),
        (["korniger frischkase", "huttenkase"], Nutrients(calories: 98, protein: 12, carbohydrates: 3, fat: 4)),
        (["thunfisch"], Nutrients(calories: 116, protein: 26, carbohydrates: 0, fat: 1)),
        (["lachs"], Nutrients(calories: 208, protein: 20, carbohydrates: 0, fat: 13)),
        (["eier", "ei "], Nutrients(calories: 143, protein: 13, carbohydrates: 1, fat: 10)),
        (["apfel"], Nutrients(calories: 52, protein: 0.3, carbohydrates: 14, fat: 0.2)),
        (["banane"], Nutrients(calories: 89, protein: 1.1, carbohydrates: 23, fat: 0.3)),
        (["orange"], Nutrients(calories: 47, protein: 0.9, carbohydrates: 12, fat: 0.1)),
        (["brokkoli"], Nutrients(calories: 34, protein: 2.8, carbohydrates: 7, fat: 0.4)),
        (["gurke"], Nutrients(calories: 15, protein: 0.7, carbohydrates: 3.6, fat: 0.1)),
        (["tomate"], Nutrients(calories: 18, protein: 0.9, carbohydrates: 3.9, fat: 0.2))
    ]
}
