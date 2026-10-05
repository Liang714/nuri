import Testing
import NuriDomain
import NutritionEngine
import ActivityEngine

/// Compiles against the public API only (no `@testable`), the way the app target sees the engines.
@Suite struct PublicAPITests {
    @Test func outputAndCatalogTypesHavePublicInitializers() {
        let range = EnergyRange(low: 80, estimate: 100, high: 125)
        #expect(range.estimate == 100)

        let item = PlanItem(kind: .aerobic, activityId: "walking", intensity: .moderate, met: 3.5,
                            minutesLow: 25, minutesHigh: 30, kcal: range)
        #expect(item.minutesHigh == 30 && item.kcal == range)

        let weekly = WeeklyTargets(goalMinutes: 150, thisWeekMinutes: 90, strengthSessions: 2, balanceSessions: 0)
        #expect(weekly.thisWeekMinutes == 90)

        let plan = MovementPlan(items: [item], weekly: weekly, notices: [.progressingGradually],
                                rationale: [.whoPhysicalActivity2020])
        #expect(plan.items == [item] && plan.weekly == weekly)

        let option = EquivalentOption(activityId: "walking", intensity: .moderate, met: 3.5, minutesLow: 30,
                                      minutesHigh: 40, highIsOpenEnded: false, suggestSplitting: false)
        #expect(option.minutesLow == 30)

        let pair = DuplicatePair(firstId: "a", secondId: "b")
        #expect(pair.secondId == "b")

        let met = METValues(light: 2.8, moderate: 3.5, vigorous: nil)
        #expect(met.value(for: .moderate) == 3.5)

        let activity = ActivityType(id: "walking", category: .aerobic, met: met, equipment: [], tags: ["low_impact"])
        #expect(activity.isLowImpact)

        let estimate = EnergyTargetEstimate(bmrKcal: 1780, tdeeKcal: 2759, adjustmentKcal: 0, targetKcal: 2760,
                                            raisedToMinimum: false, lossNotAppliedUnderweight: false,
                                            method: "mifflin_st_jeor_1990")
        #expect(estimate.targetKcal == 2760)

        let recipe = RecipeNutrition(total: NutrientProfile(energyKcal: 400), perServing: NutrientProfile(energyKcal: 200),
                                     per100g: NutrientProfile(energyKcal: 100), totalGrams: 400)
        #expect(recipe.perServing.energyKcal == 200)

        let ledger = DailyLedger(foodKcal: 1500, activityKcalBySource: [.manualMET: 200], totalActivityKcal: 200,
                                 baseTargetKcal: 2000, creditedActivityKcal: 0, adjustedTargetKcal: 2000,
                                 remainingKcal: 500)
        #expect(ledger.remainingKcal == 500)
    }

    @Test func engineEntryPointsAreCallable() throws {
        let catalog = try METCatalog.bundled()
        let profile = BodyProfile(ageYears: 30, sex: .female, heightCm: 165, weightKg: 60,
                                  activityLevel: .lightlyActive, goal: .maintain)
        let plan = try MovementPlanner.plan(MovementPlanInput(profile: profile, bmiStandard: .who), catalog: catalog)
        #expect(!plan.items.isEmpty)

        let input = EquivalentsInput(targetKcal: 200, weightKg: 60, preferredActivityIds: ["walking"],
                                     availableMinutes: nil, equipment: [], mobility: [], sensitiveMode: false,
                                     enabled: true)
        guard case .options(let options) = ActivityEquivalents.recommend(input, catalog: catalog) else {
            Issue.record("expected options"); return
        }
        #expect(options.first?.activityId == "walking")
    }
}
