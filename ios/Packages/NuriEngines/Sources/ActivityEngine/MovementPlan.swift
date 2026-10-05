import NuriDomain
import NutritionEngine

/// Simplified pre-activity readiness screen (adapted from PAR-Q+). Any "yes" → clinician clearance first.
public enum ReadinessQuestion: String, Codable, Sendable, CaseIterable {
    case heartCondition, chestPainDuringActivity, dizzinessOrFainting, boneOrJointProblem,
         bloodPressureMedication, pregnancy, otherMedicalReason
}

public struct ReadinessScreen: Codable, Sendable, Equatable {
    public var yesAnswers: Set<ReadinessQuestion>
    public init(yesAnswers: Set<ReadinessQuestion>) { self.yesAnswers = yesAnswers }
    public var needsClearance: Bool { !yesAnswers.isEmpty }
}

public struct WeeklyActivitySummary: Sendable, Equatable {
    /// Moderate-equivalent minutes so far this week (1 vigorous minute counts as 2, per WHO).
    /// Callers must build this (and `previousWeekModerateEquivalentMinutes`) by summing
    /// `MovementPlanner.moderateEquivalentMinutes(met:minutes:)` over the week's logged activities:
    /// >= 6 MET counts double, 3 to < 6 MET counts once, < 3 MET does not count.
    public var moderateEquivalentMinutes: Double
    public var strengthSessions: Int
    public var balanceSessions: Int
    public var didStrengthYesterday: Bool
    /// Nil when there is no history yet.
    public var previousWeekModerateEquivalentMinutes: Double?

    public init(moderateEquivalentMinutes: Double = 0, strengthSessions: Int = 0, balanceSessions: Int = 0,
                didStrengthYesterday: Bool = false, previousWeekModerateEquivalentMinutes: Double? = nil) {
        self.moderateEquivalentMinutes = moderateEquivalentMinutes
        self.strengthSessions = strengthSessions
        self.balanceSessions = balanceSessions
        self.didStrengthYesterday = didStrengthYesterday
        self.previousWeekModerateEquivalentMinutes = previousWeekModerateEquivalentMinutes
    }
}

public struct MovementPlanInput: Sendable {
    public var profile: BodyProfile
    public var bmiStandard: BMIStandard
    public var readiness: ReadinessScreen
    public var preferredActivityIds: [String]
    public var equipment: Set<String>
    public var mobility: Set<MobilityPreference>
    public var availableMinutesToday: Int?
    public var week: WeeklyActivitySummary
    public var daysRemainingInWeekIncludingToday: Int
    /// Total daily deficit for gradual loss (clamped to 0…500 kcal; non-finite → 250).
    public var lossDeficitKcal: Double
    /// Part of that deficit planned through activity (clamped to 0…0.5; non-finite → 0.5). The rest comes from the
    /// food target: pass `GoalAdjustmentPolicy.foodAdjustment(lossDeficitKcal:activityShare:)` with the same two
    /// values as `adjustmentKcal` to `EnergyTargetCalculator.estimate`.
    public var activityShareOfDeficit: Double
    public var sensitiveMode: Bool

    public init(profile: BodyProfile, bmiStandard: BMIStandard, readiness: ReadinessScreen = .init(yesAnswers: []),
                preferredActivityIds: [String] = [], equipment: Set<String> = [], mobility: Set<MobilityPreference> = [],
                availableMinutesToday: Int? = nil, week: WeeklyActivitySummary = .init(),
                daysRemainingInWeekIncludingToday: Int = 7, lossDeficitKcal: Double = 250,
                activityShareOfDeficit: Double = 0.5, sensitiveMode: Bool = false) {
        self.profile = profile
        self.bmiStandard = bmiStandard
        self.readiness = readiness
        self.preferredActivityIds = preferredActivityIds
        self.equipment = equipment
        self.mobility = mobility
        self.availableMinutesToday = availableMinutesToday
        self.week = week
        self.daysRemainingInWeekIncludingToday = daysRemainingInWeekIncludingToday
        self.lossDeficitKcal = lossDeficitKcal
        self.activityShareOfDeficit = activityShareOfDeficit
        self.sensitiveMode = sensitiveMode
    }
}

public enum PlanItemKind: String, Sendable { case aerobic, strength, balance }

public struct PlanItem: Equatable, Sendable {
    public let kind: PlanItemKind
    public let activityId: String
    public let intensity: Intensity
    public let met: Double
    public let minutesLow: Int
    public let minutesHigh: Int
    /// Nil in sensitive mode or clearance plans.
    public let kcal: EnergyRange?
}

public enum PlanNotice: String, Sendable {
    case clinicianClearanceRecommended, underweightNoLossPlan, cappedAtDailyMaximum,
         limitedByAvailableTime, weeklyGoalReached, progressingGradually, lowImpactSelected
}

/// Evidence shown in the "why this plan" drawer.
public enum PlanRationale: String, Sendable {
    case whoPhysicalActivity2020, acsmWeightManagement2009, metCompendium, progressionTenPercent
}

public struct WeeklyTargets: Equatable, Sendable {
    public let goalMinutes: Int
    public let thisWeekMinutes: Int
    public let strengthSessions: Int
    public let balanceSessions: Int
}

public struct MovementPlan: Equatable, Sendable {
    public let items: [PlanItem]
    public let weekly: WeeklyTargets
    public let notices: [PlanNotice]
    public let rationale: [PlanRationale]
}
