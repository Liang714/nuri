import NuriDomain

public enum EnergyFormula {
    /// Mifflin MD, St Jeor ST, et al. Am J Clin Nutr. 1990;51(2):241-7.
    public static func mifflinStJeorBMR(weightKg: Double, heightCm: Double, ageYears: Int,
                                        sex: SexForEquation) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        return sex == .male ? base + 5 : base - 161
    }

    public static func tdee(bmr: Double, activityLevel: ActivityLevel) -> Double {
        bmr * activityLevel.factor
    }
}

public enum GoalAdjustmentPolicy {
    public static let defaultLossKcal = 250.0
    public static let maxLossKcal = 500.0
    public static let defaultGainKcal = 200.0
    public static let maxGainKcal = 500.0
    /// Part of a gradual-loss deficit planned through activity (spec: the user picks the split).
    public static let defaultActivityShare = 0.5
    public static let maxActivityShare = 0.5

    /// The gradual-loss deficit and its activity share exactly as both engines use them: deficit clamped to
    /// 0…500 kcal, share to 0…0.5. Non-finite values fall back to the defaults (250 kcal, 0.5).
    /// `MovementPlanner` plans `deficitKcal × activityShare` through activity; `foodAdjustment` takes the rest.
    public static func lossSplit(deficitKcal: Double,
                                 activityShare: Double) -> (deficitKcal: Double, activityShare: Double) {
        let d = deficitKcal.isFinite ? deficitKcal : defaultLossKcal
        let s = activityShare.isFinite ? activityShare : defaultActivityShare
        return (min(maxLossKcal, max(0, d)), min(maxActivityShare, max(0, s)))
    }

    /// Food-target part of a gradual-loss deficit: −deficit × (1 − activity share), after `lossSplit` clamping.
    /// The app passes this as `adjustmentKcal` to `EnergyTargetCalculator.estimate` for loss goals, with the same
    /// deficit and share it passes to `MovementPlanInput`, so food + activity never exceed 500 kcal/day.
    public static func foodAdjustment(lossDeficitKcal: Double, activityShare: Double) -> Double {
        let split = lossSplit(deficitKcal: lossDeficitKcal, activityShare: activityShare)
        return -split.deficitKcal * (1 - split.activityShare)
    }

    public static func defaultAdjustment(for goal: Goal) -> Double {
        switch goal {
        case .gradualLoss: -defaultLossKcal
        case .gradualGain: defaultGainKcal
        default: 0
        }
    }

    public static func clamp(_ adjustment: Double, for goal: Goal) -> Double {
        switch goal {
        case .gradualLoss: min(0, max(-maxLossKcal, adjustment))
        case .gradualGain: max(0, min(maxGainKcal, adjustment))
        default: 0
        }
    }
}

/// Commonly cited minimum intake for unsupervised plans. Used to raise calculated targets
/// and to show a non-blocking "consider a registered dietitian" notice for manual targets.
public enum LowTargetPolicy {
    public static func recommendedMinimumKcal(sex: SexForEquation?) -> Double {
        sex == .male ? 1500 : 1200
    }
}

public struct EnergyTargetEstimate: Equatable, Sendable {
    public let bmrKcal: Double
    public let tdeeKcal: Double
    public let adjustmentKcal: Double
    public let targetKcal: Double
    public let raisedToMinimum: Bool
    public let lossNotAppliedUnderweight: Bool
    public let method: String

    public init(bmrKcal: Double, tdeeKcal: Double, adjustmentKcal: Double, targetKcal: Double,
                raisedToMinimum: Bool, lossNotAppliedUnderweight: Bool, method: String) {
        self.bmrKcal = bmrKcal
        self.tdeeKcal = tdeeKcal
        self.adjustmentKcal = adjustmentKcal
        self.targetKcal = targetKcal
        self.raisedToMinimum = raisedToMinimum
        self.lossNotAppliedUnderweight = lossNotAppliedUnderweight
        self.method = method
    }
}

public enum ManualTargetAssessment: Equatable, Sendable {
    case ok
    case belowRecommendedMinimum(minimumKcal: Double)
    case invalid
}

public enum EnergyTargetCalculator {
    /// Returns nil when no sex value is provided: the app offers manual target setup instead of assuming.
    public static func estimate(profile: BodyProfile,
                                adjustmentKcal: Double? = nil) throws(ProfileValidationError) -> EnergyTargetEstimate? {
        let p = try profile.validated()
        guard let sex = p.sex else { return nil }

        let bmr = EnergyFormula.mifflinStJeorBMR(weightKg: p.weightKg, heightCm: p.heightCm,
                                                 ageYears: p.ageYears, sex: sex)
        let tdee = EnergyFormula.tdee(bmr: bmr, activityLevel: p.activityLevel)

        let underweight = BMI.value(weightKg: p.weightKg, heightCm: p.heightCm) < 18.5
        let lossBlocked = p.goal == .gradualLoss && underweight
        let requested = adjustmentKcal ?? GoalAdjustmentPolicy.defaultAdjustment(for: p.goal)
        let adjustment = lossBlocked ? 0 : GoalAdjustmentPolicy.clamp(requested, for: p.goal)

        let minimum = LowTargetPolicy.recommendedMinimumKcal(sex: sex)
        let raw = tdee + adjustment
        return EnergyTargetEstimate(
            bmrKcal: bmr,
            tdeeKcal: tdee,
            adjustmentKcal: adjustment,
            targetKcal: roundTo(max(raw, minimum), step: 10),
            raisedToMinimum: raw < minimum,
            lossNotAppliedUnderweight: lossBlocked,
            method: "mifflin_st_jeor_1990"
        )
    }

    public static func assessManualTarget(_ kcal: Double, sex: SexForEquation?) -> ManualTargetAssessment {
        guard kcal.isFinite, kcal > 0, kcal <= 10_000 else { return .invalid }
        let minimum = LowTargetPolicy.recommendedMinimumKcal(sex: sex)
        return kcal < minimum ? .belowRecommendedMinimum(minimumKcal: minimum) : .ok
    }
}
