import ActivityEngine
import Foundation
import NuriDomain
import NutritionEngine
import Testing
@testable import Persistence

@Suite struct ProfileMappingTests {
    /// The engines' own reference vector: male, 30 in 2026, 180 cm, 80 kg, moderately active → TDEE 2759, target 2760.
    static func vector(goal: Goal = .maintain, sex: SexForEquation? = .male) -> ProfileDraft {
        ProfileDraft(birthYear: 1996, sex: sex, heightCm: 180, weightKg: 80, activityLevel: .moderatelyActive, goal: goal,
                     unitSystem: .metric, bmiStandard: .who)
    }

    @Test func ageIsTheYearMinusBirthYear() {
        let draft = Self.vector()
        #expect(draft.ageYears(in: 2026) == 30)
        #expect(draft.ageYears(in: 1996) == 0)
        #expect(draft.ageYears(in: 2030) == 34)
    }

    @Test func bodyProfileMapsEveryField() {
        let draft = ProfileDraft(birthYear: 1985, sex: .female, heightCm: 162.5, weightKg: 54.2, activityLevel: .veryActive,
                                 goal: .gradualGain, unitSystem: .imperial, bmiStandard: .asianPacific)
        #expect(draft.bodyProfile(inYear: 2026) == BodyProfile(ageYears: 41, sex: .female, heightCm: 162.5, weightKg: 54.2,
                                                               activityLevel: .veryActive, goal: .gradualGain))
        let noSex = Self.vector(sex: nil).bodyProfile(inYear: 2026)
        #expect(noSex.sex == nil)
        #expect(noSex.ageYears == 30)
    }

    @Test func readinessMapsTheYesAnswers() {
        var draft = Self.vector()
        #expect(draft.readiness == ReadinessScreen(yesAnswers: []))
        #expect(draft.readiness.needsClearance == false)
        draft.readinessYes = [.pregnancy, .heartCondition]
        #expect(draft.readiness == ReadinessScreen(yesAnswers: [.heartCondition, .pregnancy]))
        #expect(draft.readiness.needsClearance)
    }

    @Test func maintainUsesTheEngineVector() throws {
        let guide = try Self.vector().dailyGuide(inYear: 2026)
        guard case .calculated(let estimate) = guide else {
            Issue.record("expected .calculated, got \(guide)")
            return
        }
        #expect(estimate.targetKcal == 2760)
        #expect(estimate.adjustmentKcal == 0)
        #expect(abs(estimate.tdeeKcal - 2759) < 0.001)
        #expect(guide.kcal == 2760)
    }

    @Test func gradualLossTakesTheFoodShareOfTheDeficit() throws {
        var draft = Self.vector(goal: .gradualLoss)
        draft.lossDeficitKcal = 250
        draft.activityShare = 0.5
        let guide = try draft.dailyGuide(inYear: 2026)
        guard case .calculated(let estimate) = guide else {
            Issue.record("expected .calculated, got \(guide)")
            return
        }
        #expect(estimate.adjustmentKcal == -125)
        // Verified against the engine's own TDEE rather than a hand-rounded number.
        #expect(estimate.targetKcal == roundTo(estimate.tdeeKcal - 125, step: 10))
        #expect(estimate.targetKcal == 2630)
        #expect(guide.kcal == 2630)
    }

    @Test func gradualLossHonoursTheDraftsOwnDeficitAndShare() throws {
        var draft = Self.vector(goal: .gradualLoss)
        draft.lossDeficitKcal = 500
        draft.activityShare = 0
        guard case .calculated(let estimate) = try draft.dailyGuide(inYear: 2026) else {
            Issue.record("expected .calculated")
            return
        }
        #expect(estimate.adjustmentKcal == -500)
        #expect(estimate.targetKcal == roundTo(estimate.tdeeKcal - 500, step: 10))
    }

    @Test func otherGoalsLeaveTheAdjustmentToTheEngineDefault() throws {
        // The loss fields on the draft are ignored unless the goal is gradual loss.
        var gain = Self.vector(goal: .gradualGain)
        gain.lossDeficitKcal = 500
        gain.activityShare = 0
        guard case .calculated(let estimate) = try gain.dailyGuide(inYear: 2026) else {
            Issue.record("expected .calculated")
            return
        }
        #expect(estimate.adjustmentKcal == GoalAdjustmentPolicy.defaultGainKcal)
        #expect(estimate.targetKcal == roundTo(estimate.tdeeKcal + 200, step: 10))
    }

    @Test func noSexAndNoManualNumberNeedsAManualTarget() throws {
        let guide = try Self.vector(sex: nil).dailyGuide(inYear: 2026)
        #expect(guide == .needsManualTarget)
        #expect(guide.kcal == nil)
    }

    @Test func manualTargetWinsAndIsAssessed() throws {
        var noSex = Self.vector(sex: nil)
        noSex.manualTargetKcal = 1800
        let ok = try noSex.dailyGuide(inYear: 2026)
        #expect(ok == .manual(kcal: 1800, assessment: .ok))
        #expect(ok.kcal == 1800)

        // A manual number beats the calculation even when a sex is given.
        var male = Self.vector()
        male.manualTargetKcal = 2000
        #expect(try male.dailyGuide(inYear: 2026) == .manual(kcal: 2000, assessment: .ok))

        var female = Self.vector(sex: .female)
        female.manualTargetKcal = 1100
        let low = try female.dailyGuide(inYear: 2026)
        #expect(low == .manual(kcal: 1100, assessment: .belowRecommendedMinimum(minimumKcal: 1200)))
        #expect(low.kcal == 1100)

        var silly = Self.vector()
        silly.manualTargetKcal = 0
        #expect(try silly.dailyGuide(inYear: 2026) == .manual(kcal: 0, assessment: .invalid))
    }

    @Test func trackingWithoutAGuideGivesNone() throws {
        var draft = Self.vector()
        draft.tracksWithoutGuide = true
        #expect(try draft.dailyGuide(inYear: 2026) == .none)
        #expect(try draft.dailyGuide(inYear: 2026).kcal == nil)

        // Even a stored manual number is not shown when the person chose to track without a guide.
        draft.manualTargetKcal = 1800
        #expect(try draft.dailyGuide(inYear: 2026) == .none)
    }

    @Test func underEighteenThrowsAgeOutOfRange() {
        let draft = ProfileDraft(birthYear: 2010, sex: .male, heightCm: 170, weightKg: 60, activityLevel: .sedentary,
                                 goal: .maintain, unitSystem: .metric, bmiStandard: .who)
        #expect(throws: ProfileValidationError.ageOutOfRange(16)) {
            try draft.dailyGuide(inYear: 2026)
        }
    }

    @Test func outOfRangeBodyValuesThrowTheirOwnErrors() {
        var tall = Self.vector()
        tall.heightCm = 300
        #expect(throws: ProfileValidationError.heightOutOfRange(300)) { try tall.dailyGuide(inYear: 2026) }
        var light = Self.vector()
        light.weightKg = 10
        #expect(throws: ProfileValidationError.weightOutOfRange(10)) { try light.dailyGuide(inYear: 2026) }
    }
}
