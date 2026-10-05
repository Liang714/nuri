import Testing
import NuriDomain
@testable import NutritionEngine

@Suite struct EnergyTargetsTests {
    let male = BodyProfile(ageYears: 30, sex: .male, heightCm: 180, weightKg: 80,
                           activityLevel: .moderatelyActive, goal: .maintain)
    let female = BodyProfile(ageYears: 28, sex: .female, heightCm: 165, weightKg: 60,
                             activityLevel: .sedentary, goal: .maintain)

    @Test func mifflinStJeorVectors() {
        #expect(EnergyFormula.mifflinStJeorBMR(weightKg: 80, heightCm: 180, ageYears: 30, sex: .male) == 1780)
        #expect(EnergyFormula.mifflinStJeorBMR(weightKg: 60, heightCm: 165, ageYears: 28, sex: .female) == 1330.25)
    }

    @Test func tdee() {
        #expect(approx(EnergyFormula.tdee(bmr: 1780, activityLevel: .moderatelyActive), 2759))
    }

    @Test func maintainTargetRoundedToTen() throws {
        let e = try #require(try EnergyTargetCalculator.estimate(profile: male))
        #expect(e.targetKcal == 2760)
        #expect(e.adjustmentKcal == 0)
        #expect(e.method == "mifflin_st_jeor_1990")
        #expect(!e.raisedToMinimum)
    }

    @Test func gradualLossDefaultIsMinus250() throws {
        var p = male; p.goal = .gradualLoss
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p))
        #expect(e.adjustmentKcal == -250)
        #expect(e.targetKcal == 2510)
    }

    @Test func lossIsClampedToConservativeMax() throws {
        var p = male; p.goal = .gradualLoss
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p, adjustmentKcal: -1000))
        #expect(e.adjustmentKcal == -500)
    }

    @Test func gradualGainDefaultIsPlus200() throws {
        var p = male; p.goal = .gradualGain
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p))
        #expect(e.adjustmentKcal == 200)
    }

    @Test func calculatedTargetNeverBelowRecommendedMinimum() throws {
        var p = female; p.goal = .gradualLoss
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p, adjustmentKcal: -500))
        #expect(e.targetKcal == 1200)
        #expect(e.raisedToMinimum)
    }

    @Test func lossNotAppliedWhenUnderweight() throws {
        let p = BodyProfile(ageYears: 25, sex: .female, heightCm: 170, weightKg: 50,
                            activityLevel: .lightlyActive, goal: .gradualLoss)
        let e = try #require(try EnergyTargetCalculator.estimate(profile: p))
        #expect(e.adjustmentKcal == 0)
        #expect(e.lossNotAppliedUnderweight)
    }

    @Test func noSexMeansManualSetup() throws {
        var p = male; p.sex = nil
        #expect(try EnergyTargetCalculator.estimate(profile: p) == nil)
    }

    @Test func invalidProfileThrows() {
        var p = male; p.ageYears = 16
        #expect(throws: ProfileValidationError.ageOutOfRange(16)) {
            try EnergyTargetCalculator.estimate(profile: p)
        }
    }

    @Test func manualTargetAssessmentWarnsButDoesNotBlock() {
        #expect(EnergyTargetCalculator.assessManualTarget(1100, sex: .female) == .belowRecommendedMinimum(minimumKcal: 1200))
        #expect(EnergyTargetCalculator.assessManualTarget(1400, sex: .male) == .belowRecommendedMinimum(minimumKcal: 1500))
        #expect(EnergyTargetCalculator.assessManualTarget(2000, sex: nil) == .ok)
        #expect(EnergyTargetCalculator.assessManualTarget(0, sex: .male) == .invalid)
        #expect(EnergyTargetCalculator.assessManualTarget(20000, sex: .male) == .invalid)
    }
}
