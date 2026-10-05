import NuriDomain
import NutritionEngine

public enum MovementPlanner {
    public static let dailyMaxMinutes = 90
    public static let minimumSessionMinutes = 10
    public static let whoBaseWeeklyMinutes = 150
    public static let whoUpperWeeklyMinutes = 300

    /// WHO 2020: 150–300 min/week moderate. For gradual loss, the activity share of the deficit
    /// sets the weekly minutes (ACSM 2009: 150–250+ min/week), bounded to 150…300.
    public static func weeklyAerobicGoalMinutes(goal: Goal, weightKg: Double, primaryModerateMET: Double,
                                                lossDeficitKcal: Double, activityShare: Double) -> Int {
        switch goal {
        case .performance:
            return whoUpperWeeklyMinutes
        case .gradualLoss:
            let deficit = min(500, max(0, lossDeficitKcal))
            let share = min(0.5, max(0, activityShare))
            let dailyKcal = deficit * share
            let dailyMinutes = dailyKcal / (primaryModerateMET * weightKg) * 60
            let weekly = roundTo(dailyMinutes * 7, step: 5)
            return Int(min(Double(whoUpperWeeklyMinutes), max(Double(whoBaseWeeklyMinutes), weekly)))
        default:
            return whoBaseWeeklyMinutes
        }
    }

    public static func startingWeeklyMinutes(for level: ActivityLevel) -> Int {
        switch level {
        case .sedentary: 60
        case .lightlyActive: 90
        default: whoBaseWeeklyMinutes
        }
    }

    /// Ramp toward the goal, increasing at most 10% over last week.
    public static func effectiveWeeklyMinutes(goal: Int, level: ActivityLevel, previousWeek: Double?) -> Int {
        let start = Double(startingWeeklyMinutes(for: level))
        let ramp = previousWeek.map { max(start, roundTo($0 * 1.10, step: 5)) } ?? start
        return Int(min(Double(goal), ramp))
    }

    public static func strengthSessionsGoal(goal: Goal) -> Int {
        goal == .gradualGain || goal == .performance ? 3 : 2
    }

    /// WHO 2020: adults 65+ add multicomponent balance activity ≥ 3 days/week.
    public static func balanceSessionsGoal(ageYears: Int) -> Int {
        ageYears >= 65 ? 3 : 0
    }

    public static func plan(_ input: MovementPlanInput, catalog: METCatalog) -> MovementPlan {
        let p = input.profile
        let bmi = BMI.value(weightKg: p.weightKg, heightCm: p.heightCm)
        let bmiCategory = BMI.category(for: bmi, standard: input.bmiStandard)
        let strengthGoal = strengthSessionsGoal(goal: p.goal)
        let balanceGoal = balanceSessionsGoal(ageYears: p.ageYears)

        if input.readiness.needsClearance {
            return clearancePlan(input, catalog: catalog, strengthGoal: strengthGoal, balanceGoal: balanceGoal)
        }

        var notices: [PlanNotice] = []
        var rationale: [PlanRationale] = [.whoPhysicalActivity2020]

        var goal = p.goal
        if goal == .gradualLoss && bmiCategory == .underweight {
            goal = .maintain
            notices.append(.underweightNoLossPlan)
        }

        let requireLowImpact = bmiCategory == .obese
        let allowVigorous = p.activityLevel >= .moderatelyActive && bmiCategory != .obese && goal == .performance
        let aerobicChoice = choose(.aerobic, input: input, catalog: catalog, requireLowImpact: requireLowImpact)
        if requireLowImpact, aerobicChoice != nil,
           input.preferredActivityIds.contains(where: { id in catalog.activity(id: id).map { !$0.isLowImpact } ?? false }) {
            notices.append(.lowImpactSelected)
        }

        let primaryModerateMET = aerobicChoice?.met.moderate ?? 3.5
        let weeklyGoal = weeklyAerobicGoalMinutes(goal: goal, weightKg: p.weightKg, primaryModerateMET: primaryModerateMET,
                                                  lossDeficitKcal: input.lossDeficitKcal,
                                                  activityShare: input.activityShareOfDeficit)
        if goal == .gradualLoss { rationale.append(.acsmWeightManagement2009) }
        let thisWeek = effectiveWeeklyMinutes(goal: weeklyGoal, level: p.activityLevel,
                                              previousWeek: input.week.previousWeekModerateEquivalentMinutes)
        if thisWeek < weeklyGoal {
            notices.append(.progressingGradually)
            rationale.append(.progressionTenPercent)
        }

        var items: [PlanItem] = []
        var minutesLeftToday = input.availableMinutesToday.map { Double($0) }

        let remaining = max(0, Double(thisWeek) - input.week.moderateEquivalentMinutes)
        if remaining <= 0 {
            notices.append(.weeklyGoalReached)
        } else if let activity = aerobicChoice {
            let days = Double(max(1, min(7, input.daysRemainingInWeekIncludingToday)))
            var moderateMinutes = max(Double(minimumSessionMinutes), ceilTo(remaining / days, step: 5))
            if moderateMinutes > Double(dailyMaxMinutes) {
                moderateMinutes = Double(dailyMaxMinutes)
                notices.append(.cappedAtDailyMaximum)
            }
            let intensity: Intensity = (allowVigorous && activity.met.vigorous != nil) ? .vigorous : .moderate
            let met = activity.met.value(for: intensity) ?? activity.met.light ?? primaryModerateMET
            var minutes = met >= 6 && intensity == .vigorous ? moderateMinutes / 2 : moderateMinutes
            if let available = minutesLeftToday, minutes > available {
                minutes = available
                notices.append(.limitedByAvailableTime)
            }
            if minutes > 0 {
                let item = makeItem(.aerobic, activity: activity, intensity: intensity, met: met,
                                    minutes: minutes, cap: minutesLeftToday, input: input)
                items.append(item)
                minutesLeftToday = minutesLeftToday.map { $0 - Double(item.minutesHigh) }
            }
        }

        let strengthRemaining = strengthGoal - input.week.strengthSessions
        let daysLeft = max(1, input.daysRemainingInWeekIncludingToday)
        if strengthRemaining > 0,
           strengthRemaining >= daysLeft || !input.week.didStrengthYesterday,
           (minutesLeftToday ?? .infinity) >= 15,
           let activity = choose(.strength, input: input, catalog: catalog, requireLowImpact: requireLowImpact),
           let met = activity.met.moderate {
            items.append(fixedItem(.strength, activity: activity, intensity: .moderate, met: met,
                                   low: 15, high: 25, input: input))
            minutesLeftToday = minutesLeftToday.map { $0 - 25 }
        }

        if balanceGoal - input.week.balanceSessions > 0,
           !input.mobility.contains(.seatedOnly),
           (minutesLeftToday ?? .infinity) >= 10,
           let activity = catalog.activity(id: "tai_chi"),
           let met = activity.met.light {
            items.append(fixedItem(.balance, activity: activity, intensity: .light, met: met,
                                   low: 10, high: 15, input: input))
        }

        if !input.sensitiveMode && !items.isEmpty { rationale.append(.metCompendium) }

        return MovementPlan(
            items: items,
            weekly: WeeklyTargets(goalMinutes: weeklyGoal, thisWeekMinutes: thisWeek,
                                  strengthSessions: strengthGoal, balanceSessions: balanceGoal),
            notices: notices,
            rationale: rationale
        )
    }

    // MARK: - Helpers

    private static func clearancePlan(_ input: MovementPlanInput, catalog: METCatalog,
                                      strengthGoal: Int, balanceGoal: Int) -> MovementPlan {
        let seated = input.mobility.contains(.seatedOnly)
        let activityId = seated ? "cycling_stationary" : "walking"
        var items: [PlanItem] = []
        if let activity = catalog.activity(id: activityId),
           Set(activity.equipment).isSubset(of: input.equipment),
           let met = activity.met.light {
            items.append(PlanItem(kind: .aerobic, activityId: activity.id, intensity: .light, met: met,
                                  minutesLow: 10, minutesHigh: 20, kcal: nil))
        }
        return MovementPlan(
            items: items,
            weekly: WeeklyTargets(goalMinutes: whoBaseWeeklyMinutes, thisWeekMinutes: 0,
                                  strengthSessions: strengthGoal, balanceSessions: balanceGoal),
            notices: [.clinicianClearanceRecommended],
            rationale: [.whoPhysicalActivity2020]
        )
    }

    /// Preferred eligible activity first, then walking (aerobic) / bodyweight (strength), then catalog order.
    private static func choose(_ category: ActivityCategory, input: MovementPlanInput, catalog: METCatalog,
                               requireLowImpact: Bool) -> ActivityType? {
        let eligible = catalog.eligible(category: category, equipment: input.equipment,
                                        mobility: input.mobility, requireLowImpact: requireLowImpact)
        if let preferred = input.preferredActivityIds.lazy.compactMap({ id in eligible.first { $0.id == id } }).first {
            return preferred
        }
        let fallbackId = category == .aerobic ? "walking" : "strength_bodyweight"
        return eligible.first { $0.id == fallbackId } ?? eligible.first
    }

    private static func makeItem(_ kind: PlanItemKind, activity: ActivityType, intensity: Intensity, met: Double,
                                 minutes: Double, cap: Double?, input: MovementPlanInput) -> PlanItem {
        let upper = min(Double(dailyMaxMinutes), cap ?? .infinity)
        let low = max(5, min(upper, roundTo(minutes * 0.9, step: 5)))
        let high = max(low, min(upper, roundTo(minutes * 1.1, step: 5)))
        return PlanItem(kind: kind, activityId: activity.id, intensity: intensity, met: met,
                        minutesLow: Int(low), minutesHigh: Int(high),
                        kcal: kcalRange(met: met, low: low, estimate: minutes, high: high, input: input))
    }

    private static func fixedItem(_ kind: PlanItemKind, activity: ActivityType, intensity: Intensity, met: Double,
                                  low: Int, high: Int, input: MovementPlanInput) -> PlanItem {
        PlanItem(kind: kind, activityId: activity.id, intensity: intensity, met: met,
                 minutesLow: low, minutesHigh: high,
                 kcal: kcalRange(met: met, low: Double(low), estimate: Double(low + high) / 2,
                                 high: Double(high), input: input))
    }

    private static func kcalRange(met: Double, low: Double, estimate: Double, high: Double,
                                  input: MovementPlanInput) -> EnergyRange? {
        guard !input.sensitiveMode else { return nil }
        let w = input.profile.weightKg
        return EnergyRange(
            low: EnergyEstimator.kcal(met: met, weightKg: w, minutes: low) * EnergyEstimator.lowFactor,
            estimate: EnergyEstimator.kcal(met: met, weightKg: w, minutes: estimate),
            high: EnergyEstimator.kcal(met: met, weightKg: w, minutes: high) * EnergyEstimator.highFactor
        )
    }
}
