import ActivityEngine
import Foundation
import NuriDomain
import NutritionEngine

/// What the app shows as the person's daily energy guide, and where it came from.
public enum DailyGuide: Equatable, Sendable {
    /// Calculated from the profile (Mifflin-St Jeor).
    case calculated(EnergyTargetEstimate)
    /// A number the person typed, with the engine's non-blocking assessment of it.
    case manual(kcal: Double, assessment: ManualTargetAssessment)
    /// No sex value was given and no manual number was entered: ask for a manual target instead of assuming.
    case needsManualTarget
    /// The person chose to track without a guide.
    case none

    /// The daily kcal guide, or nil when there is none to show.
    public var kcal: Double? {
        switch self {
        case .calculated(let estimate): estimate.targetKcal
        case .manual(let kcal, _): kcal
        case .needsManualTarget, .none: nil
        }
    }
}

extension ProfileDraft {
    /// Age in whole years by calendar year (the app stores year of birth only).
    public func ageYears(in year: Int) -> Int {
        year - birthYear
    }

    public func bodyProfile(inYear year: Int) -> BodyProfile {
        BodyProfile(ageYears: ageYears(in: year), sex: sex, heightCm: heightCm, weightKg: weightKg,
                    activityLevel: activityLevel, goal: goal)
    }

    public var readiness: ReadinessScreen {
        ReadinessScreen(yesAnswers: readinessYes)
    }

    /// The guide for `year`. A manual number wins over the calculation; tracking without a guide wins over both.
    public func dailyGuide(inYear year: Int) throws(ProfileValidationError) -> DailyGuide {
        if tracksWithoutGuide { return .none }
        if let manualTargetKcal {
            return .manual(kcal: manualTargetKcal,
                           assessment: EnergyTargetCalculator.assessManualTarget(manualTargetKcal, sex: sex))
        }
        // Only a loss goal carries a person-chosen split; other goals use the engine's default adjustment.
        let adjustment: Double? = goal == .gradualLoss
            ? GoalAdjustmentPolicy.foodAdjustment(lossDeficitKcal: lossDeficitKcal, activityShare: activityShare)
            : nil
        guard let estimate = try EnergyTargetCalculator.estimate(profile: bodyProfile(inYear: year),
                                                                 adjustmentKcal: adjustment) else {
            return .needsManualTarget
        }
        return .calculated(estimate)
    }
}
