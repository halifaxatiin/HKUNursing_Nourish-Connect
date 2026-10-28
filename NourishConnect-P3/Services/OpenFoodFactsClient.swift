import Foundation

enum LookupResult: Equatable {
    /// The product was found and has at least a sugar or sodium value.
    case found(name: String?, facts: NutritionFacts)
    /// Not in the database, or too little nutrition data to rate. The app then asks for a label photo.
    case notFound
}

/// Reads a product from Open Food Facts by barcode.
/// Open Food Facts is a free, open database (ODbL licence). Check its licence terms and its
/// Hong Kong coverage before relying on it, and set a real contact address in the User-Agent
/// as its API guidelines ask.
struct OpenFoodFactsClient {
    var session: URLSession = .shared

    func lookup(barcode: String) async throws -> LookupResult {
        let digits = barcode.filter(\.isNumber)
        guard (8...14).contains(digits.count) else { return .notFound }

        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json")!
        components.queryItems = [
            URLQueryItem(name: "fields", value: "product_name,product_name_zh,nutriments")
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 8)
        // TODO: replace with the team's real contact address before wider use.
        request.setValue("NourishConnect/0.2 (student project; contact: your-email@example.com)",
                         forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            return .notFound
        }
        return OpenFoodFactsParser.parse(data)
    }
}

/// Turns an Open Food Facts JSON reply into a LookupResult. Pure, so it is unit tested.
enum OpenFoodFactsParser {
    static func parse(_ data: Data) -> LookupResult {
        guard
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            number(root["status"]) == 1,
            let product = root["product"] as? [String: Any]
        else { return .notFound }

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]

        // Open Food Facts stores values per 100 g, and sodium in grams.
        var facts = NutritionFacts()
        facts.basis = .per100g
        facts.energyKcal = number(nutriments["energy-kcal_100g"])
        facts.proteinG = number(nutriments["proteins_100g"])
        facts.fatG = number(nutriments["fat_100g"])
        facts.satFatG = number(nutriments["saturated-fat_100g"])
        facts.transFatG = number(nutriments["trans-fat_100g"])
        facts.carbsG = number(nutriments["carbohydrates_100g"])
        facts.sugarsG = number(nutriments["sugars_100g"])
        if let sodiumG = number(nutriments["sodium_100g"]) {
            facts.sodiumMg = sodiumG * 1000
        } else if let saltG = number(nutriments["salt_100g"]) {
            facts.sodiumMg = saltG * 400
        }

        guard facts.hasRatableValues else { return .notFound }

        let chinese = (product["product_name_zh"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let other = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = [chinese, other].compactMap { $0 }.first { !$0.isEmpty }

        return .found(name: name, facts: facts)
    }

    /// Open Food Facts sometimes sends numbers as text.
    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }
}
