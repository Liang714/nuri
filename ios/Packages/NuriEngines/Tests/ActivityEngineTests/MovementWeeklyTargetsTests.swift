import Testing
import NuriDomain
@testable import ActivityEngine

@Suite struct MovementWeeklyTargetsTests {
    @Test func whoBaselineForMaintain() {
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .maintain, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 250, activityShare: 0.5) == 150)
    }

    @Test func lossGoalDerivesFromActivityShareAndIsBounded() {
        // 250 × 0.5 = 125 kcal/day → 30.6 min/day at 3.5 MET, 70 kg → 214 → 215 min/week
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .gradualLoss, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 250, activityShare: 0.5) == 215)
        // No activity share → WHO baseline
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .gradualLoss, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 250, activityShare: 0) == 150)
        // Large deficit → capped at the WHO upper value of 300
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .gradualLoss, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 500, activityShare: 0.5) == 300)
        // Deficit and share inputs are clamped (≤ 500 kcal, ≤ 0.5)
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .gradualLoss, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 2000, activityShare: 1) == 300)
    }

    @Test func performanceUsesUpperGuideline() {
        #expect(MovementPlanner.weeklyAerobicGoalMinutes(goal: .performance, weightKg: 70, primaryModerateMET: 3.5,
                                                         lossDeficitKcal: 250, activityShare: 0.5) == 300)
    }

    @Test func progressionStartsLowAndGrowsAtMost10Percent() {
        #expect(MovementPlanner.startingWeeklyMinutes(for: .sedentary) == 60)
        #expect(MovementPlanner.startingWeeklyMinutes(for: .lightlyActive) == 90)
        #expect(MovementPlanner.startingWeeklyMinutes(for: .moderatelyActive) == 150)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 150, level: .sedentary, previousWeek: nil) == 60)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 150, level: .sedentary, previousWeek: 100) == 110)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 150, level: .sedentary, previousWeek: 200) == 150)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 215, level: .moderatelyActive, previousWeek: nil) == 150)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 215, level: .moderatelyActive, previousWeek: 200) == 215)
        // Starting dose is a floor only for beginners: growth above it is capped at +10%/week.
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 150, level: .moderatelyActive, previousWeek: 30) == 60)
        #expect(MovementPlanner.effectiveWeeklyMinutes(goal: 300, level: .veryActive, previousWeek: 104) == 110)
    }

    @Test func strengthAndBalanceGoals() {
        #expect(MovementPlanner.strengthSessionsGoal(goal: .maintain) == 2)
        #expect(MovementPlanner.strengthSessionsGoal(goal: .gradualGain) == 3)
        #expect(MovementPlanner.strengthSessionsGoal(goal: .performance) == 3)
        #expect(MovementPlanner.balanceSessionsGoal(ageYears: 64) == 0)
        #expect(MovementPlanner.balanceSessionsGoal(ageYears: 65) == 3)
    }

    @Test func readinessScreen() {
        #expect(!ReadinessScreen(yesAnswers: []).needsClearance)
        #expect(ReadinessScreen(yesAnswers: [.pregnancy]).needsClearance)
    }
}
