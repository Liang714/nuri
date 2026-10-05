import Testing
import NuriDomain
@testable import NutritionEngine

@Suite struct DailyLedgerTests {
    let activity: [ActivityEnergySource: Double] = [.manualMET: 200, .wearable: 100]

    @Test func defaultModeIsBaseTargetOnly() {
        #expect(ExerciseCreditMode.default == .baseTargetOnly)
    }

    @Test func baseTargetOnlyIgnoresActivity() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .baseTargetOnly)
        #expect(l.totalActivityKcal == 300)
        #expect(l.creditedActivityKcal == 0)
        #expect(l.adjustedTargetKcal == 2000)
        #expect(l.remainingKcal == 500)
    }

    @Test func partialCredit() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .partialCredit(percent: 50))
        #expect(l.creditedActivityKcal == 150)
        #expect(l.remainingKcal == 650)
    }

    @Test func partialCreditPercentIsClamped() {
        let l = DailyLedger.compute(foodKcal: 0, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .partialCredit(percent: 150))
        #expect(l.creditedActivityKcal == 300)
    }

    @Test func negativePartialCreditPercentCreditsNothing() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .partialCredit(percent: -50))
        #expect(l.creditedActivityKcal == 0)
        #expect(l.remainingKcal == 500)
    }

    @Test func fullCredit() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .fullCredit)
        #expect(l.remainingKcal == 800)
    }

    @Test func noEnergyMathHasNoRemaining() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: activity, baseTargetKcal: 2000, mode: .noEnergyMath)
        #expect(l.remainingKcal == nil)
        #expect(l.adjustedTargetKcal == nil)
        #expect(l.totalActivityKcal == 300)
    }

    @Test func noTargetHasNoRemaining() {
        let l = DailyLedger.compute(foodKcal: 1500, activityKcalBySource: [:], baseTargetKcal: nil, mode: .fullCredit)
        #expect(l.remainingKcal == nil)
    }

    @Test func remainingCanBeNegativeAndIsNotClamped() {
        let l = DailyLedger.compute(foodKcal: 2300, activityKcalBySource: [:], baseTargetKcal: 2000, mode: .baseTargetOnly)
        #expect(l.remainingKcal == -300) // the app shows this neutrally, never as "over budget"
    }
}
