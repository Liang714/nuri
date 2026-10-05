import Testing
@testable import NutritionEngine

@Suite struct NutrientsTests {
    let egg = NutrientProfile(energyKcal: 143, proteinG: 12.6, carbsG: 0.7, fatG: 9.5, sodiumMg: 142)

    @Test func scalingKeepsMissingFieldsMissing() {
        let half = egg.scaled(by: 0.5)
        #expect(half.energyKcal == 71.5)
        #expect(half.proteinG == 6.3)
        #expect(half.fiberG == nil)
    }

    @Test func addingTreatsMissingAsUnknownOnlyWhenBothMissing() {
        let toast = NutrientProfile(energyKcal: 80, proteinG: 3, carbsG: 14, fatG: 1, fiberG: 2)
        let sum = egg + toast
        #expect(sum.energyKcal == 223)
        #expect(approx(sum.proteinG!, 15.6))
        #expect(sum.fiberG == 2)
        #expect(sum.sugarG == nil)
    }

    @Test func micronutrientsMerge() {
        let a = NutrientProfile(energyKcal: 0, micronutrients: ["iron_mg": 1, "calcium_mg": 10])
        let b = NutrientProfile(energyKcal: 0, micronutrients: ["iron_mg": 2])
        #expect((a + b).micronutrients == ["iron_mg": 3, "calcium_mg": 10])
    }

    @Test func per100gToGrams() {
        let n = NutritionMath.nutrients(per100g: egg, grams: 50)
        #expect(n.energyKcal == 71.5)
    }

    @Test func energyConsistency() {
        #expect(EnergyConsistency.check(egg) == .consistent)
        let wrong = NutrientProfile(energyKcal: 500, proteinG: 10, carbsG: 10, fatG: 1)
        #expect(EnergyConsistency.check(wrong) == .inconsistent(statedKcal: 500, computedKcal: 89))
        #expect(EnergyConsistency.check(NutrientProfile(energyKcal: 100)) == .insufficientData)
    }
}
