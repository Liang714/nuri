public struct RecipeIngredient: Sendable, Equatable {
    public let nutrientsPer100g: NutrientProfile
    public let grams: Double

    public init(nutrientsPer100g: NutrientProfile, grams: Double) {
        self.nutrientsPer100g = nutrientsPer100g
        self.grams = grams
    }
}

public struct RecipeNutrition: Sendable, Equatable {
    public let total: NutrientProfile
    public let perServing: NutrientProfile
    public let per100g: NutrientProfile?
    /// Cooked yield when given, otherwise the raw ingredient weight.
    public let totalGrams: Double
}

public enum RecipeError: Error, Equatable, Sendable {
    case noIngredients, nonPositiveServings, nonPositiveIngredientGrams, nonPositiveYield
}

public enum RecipeCalculator {
    public static func nutrition(ingredients: [RecipeIngredient], servings: Double,
                                 cookedYieldGrams: Double? = nil) throws(RecipeError) -> RecipeNutrition {
        guard !ingredients.isEmpty else { throw .noIngredients }
        guard servings.isFinite, servings > 0 else { throw .nonPositiveServings }
        guard ingredients.allSatisfy({ $0.grams.isFinite && $0.grams > 0 }) else { throw .nonPositiveIngredientGrams }
        if let y = cookedYieldGrams, !(y.isFinite && y > 0) { throw .nonPositiveYield }

        let total = ingredients.reduce(NutrientProfile.zero) {
            $0 + NutritionMath.nutrients(per100g: $1.nutrientsPer100g, grams: $1.grams)
        }
        let totalGrams = cookedYieldGrams ?? ingredients.reduce(0) { $0 + $1.grams }
        return RecipeNutrition(
            total: total,
            perServing: total.scaled(by: 1 / servings),
            per100g: totalGrams > 0 ? total.scaled(by: 100 / totalGrams) : nil,
            totalGrams: totalGrams
        )
    }
}
