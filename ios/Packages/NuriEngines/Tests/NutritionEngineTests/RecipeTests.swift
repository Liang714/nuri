import Testing
@testable import NutritionEngine

@Suite struct RecipeTests {
    let rice = RecipeIngredient(nutrientsPer100g: NutrientProfile(energyKcal: 130, proteinG: 2.7, carbsG: 28, fatG: 0.3), grams: 300)
    let chicken = RecipeIngredient(nutrientsPer100g: NutrientProfile(energyKcal: 165, proteinG: 31, carbsG: 0, fatG: 3.6), grams: 200)

    @Test func totalsAndFractionalServings() throws {
        let r = try RecipeCalculator.nutrition(ingredients: [rice, chicken], servings: 2.5)
        #expect(approx(r.total.energyKcal, 720))
        #expect(approx(r.total.proteinG!, 70.1))
        #expect(approx(r.perServing.energyKcal, 288))
        #expect(r.totalGrams == 500)
        #expect(approx(r.per100g!.energyKcal, 144))
    }

    @Test func cookedYieldChangesPer100gNotTotals() throws {
        let r = try RecipeCalculator.nutrition(ingredients: [rice, chicken], servings: 2, cookedYieldGrams: 450)
        #expect(approx(r.total.energyKcal, 720))
        #expect(approx(r.per100g!.energyKcal, 160))
        #expect(r.totalGrams == 450)
    }

    @Test func invalidInputs() {
        #expect(throws: RecipeError.noIngredients) { try RecipeCalculator.nutrition(ingredients: [], servings: 1) }
        #expect(throws: RecipeError.nonPositiveServings) { try RecipeCalculator.nutrition(ingredients: [rice], servings: 0) }
        #expect(throws: RecipeError.nonPositiveYield) {
            try RecipeCalculator.nutrition(ingredients: [rice], servings: 1, cookedYieldGrams: 0)
        }
        let bad = RecipeIngredient(nutrientsPer100g: .zero, grams: -5)
        #expect(throws: RecipeError.nonPositiveIngredientGrams) { try RecipeCalculator.nutrition(ingredients: [bad], servings: 1) }
    }
}
