import NuriDomain
import NutritionEngine

public enum MovementPlanner {
    public static let dailyMaxMinutes = 90
    public static let minimumSessionMinutes = 10
    /// `MovementPlanInput.maxSessionMinutes` is clamped to this range.
    public static let sessionCapRange = 10...90
    /// Longest clearance-plan item (light activity while clinician clearance is pending).
    public static let clearanceMaxMinutes = 20
    public static let whoBaseWeeklyMinutes = 150
    public static let whoUpperWeeklyMinutes = 300

    /// WHO 2020: 150–300 min/week moderate. For gradual loss, the activity share of the deficit
    /// sets the weekly minutes (ACSM 2009: 150–250+ min/week), bounded to 150…300.
    /// Deficit and share are clamped by `GoalAdjustmentPolicy.lossSplit`, the same rule the food side
    /// (`GoalAdjustmentPolicy.foodAdjustment`) uses, so the two parts add up to the clamped deficit.
    public static func weeklyAerobicGoalMinutes(goal: Goal, weightKg: Double, primaryModerateMET: Double,
                                                lossDeficitKcal: Double, activityShare: Double) -> Int {
        switch goal {
        case .performance:
            return whoUpperWeeklyMinutes
        case .gradualLoss:
            let split = GoalAdjustmentPolicy.lossSplit(deficitKcal: lossDeficitKcal, activityShare: activityShare)
            let dailyKcal = split.deficitKcal * split.activityShare
            let dailyMinutes = dailyKcal / (primaryModerateMET * weightKg) * 60
            let weekly = roundTo(dailyMinutes * 7, step: 5)
            return Int(min(Double(whoUpperWeeklyMinutes), max(Double(whoBaseWeeklyMinutes), weekly)))
        default:
            return whoBaseWeeklyMinutes
        }
    }

    /// WHO 2020 counting for `WeeklyActivitySummary`: a minute at >= 6 MET counts as 2 moderate minutes,
    /// a minute at 3 to < 6 MET counts as 1, and light activity (< 3 MET) does not count.
    public static func moderateEquivalentMinutes(met: Double, minutes: Double) -> Double {
        switch Intensity.forMET(met) {
        case .vigorous: minutes * 2
        case .moderate: minutes
        case .light: 0
        }
    }

    public static func startingWeeklyMinutes(for level: ActivityLevel) -> Int {
        switch level {
        case .sedentary: 60
        case .lightlyActive: 90
        default: whoBaseWeeklyMinutes
        }
    }

    /// Ramp toward the goal. 60 min/week is the beginner dose; above it, growth is capped at +10% over last week
    /// (rounded down to 5 min so rounding can never exceed the cap).
    public static func effectiveWeeklyMinutes(goal: Int, level: ActivityLevel, previousWeek: Double?) -> Int {
        guard let previousWeek else {
            return min(goal, startingWeeklyMinutes(for: level))
        }
        // The epsilon absorbs binary floating-point error (e.g. 50 × 1.1) without changing any realistic input.
        let grown = (previousWeek * 1.10 / 5 + 1e-9).rounded(.down) * 5
        return min(goal, Int(max(60, grown)))
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

        // One daily budget shared by every item: never above 90 min, never above the time the user has.
        var budget = Double(min(dailyMaxMinutes, input.availableMinutesToday ?? dailyMaxMinutes))
        let sessionCap = Double(min(sessionCapRange.upperBound, max(sessionCapRange.lowerBound, input.maxSessionMinutes)))

        if input.readiness.needsClearance {
            return clearancePlan(input, catalog: catalog, budget: budget, sessionCap: sessionCap,
                                 strengthGoal: strengthGoal, balanceGoal: balanceGoal)
        }

        var notices: [PlanNotice] = []
        func noteLimitedByTime() {
            if !notices.contains(.limitedByAvailableTime) { notices.append(.limitedByAvailableTime) }
        }
        var rationale: [PlanRationale] = [.whoPhysicalActivity2020]
        let days = Double(max(1, min(7, input.daysRemainingInWeekIncludingToday)))

        // Underweight: never a loss or performance (vigorous) plan, whatever the goal.
        var goal = p.goal
        let underweight = bmiCategory == .underweight
        if underweight {
            notices.append(.underweightNoLossPlan)
            if goal == .gradualLoss || goal == .performance { goal = .maintain }
        }

        let requireLowImpact = bmiCategory == .obese
        let allowVigorous = p.activityLevel >= .moderatelyActive && bmiCategory != .obese
            && !underweight && goal == .performance
        let aerobicChoice = choose(.aerobic, input: input, catalog: catalog, requireLowImpact: requireLowImpact,
                                   allowVigorous: allowVigorous)
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

        let remaining = max(0, Double(thisWeek) - input.week.moderateEquivalentMinutes)
        if remaining <= 0 {
            notices.append(.weeklyGoalReached)
        } else if let activity = aerobicChoice,
                  let prescription = aerobicPrescription(for: activity, allowVigorous: allowVigorous) {
            var moderateMinutes = max(Double(minimumSessionMinutes), ceilTo(remaining / days, step: 5))
            // No catch-up spikes: a single day never carries more than about two days' worth of the weekly target.
            let spikeCap = ceilTo(2 * Double(thisWeek) / 7, step: 5)
            if moderateMinutes > spikeCap {
                moderateMinutes = spikeCap
                if !notices.contains(.progressingGradually) { notices.append(.progressingGradually) }
            }
            // The spike cap keeps moderate-equivalent minutes at 90 or below (this week's target is at most 300),
            // and the budget keeps the day total at 90 or below, so no separate daily-maximum check is needed.
            // WHO: one minute at >= 6 MET counts as two moderate minutes, so the item is halved.
            var minutes = prescription.met >= 6 ? moderateMinutes / 2 : moderateMinutes
            if minutes > sessionCap {
                minutes = sessionCap
                notices.append(.cappedAtSessionMaximum)
            }
            var limitedByBudget = false
            if minutes > budget {
                minutes = budget
                limitedByBudget = true
                noteLimitedByTime()
            }
            if !(limitedByBudget && minutes < Double(minimumSessionMinutes)) {
                let item = makeItem(.aerobic, activity: activity, met: prescription.met,
                                    minutes: minutes, cap: min(budget, sessionCap), input: input)
                items.append(item)
                budget -= Double(item.minutesHigh)
            }
        } else {
            notices.append(.noSuitableActivity)
        }

        let strengthRemaining = strengthGoal - input.week.strengthSessions
        if strengthRemaining > 0,
           strengthRemaining >= Int(days) || !input.week.didStrengthYesterday,
           let activity = choose(.strength, input: input, catalog: catalog, requireLowImpact: requireLowImpact,
                                 allowVigorous: false),
           let met = activity.met.moderate {
            if budget >= 15 {
                let high = Int(min(25, budget))
                items.append(fixedItem(.strength, activity: activity, met: met, low: 15, high: high, input: input))
                budget -= Double(high)
            } else {
                noteLimitedByTime()
            }
        }

        if balanceGoal - input.week.balanceSessions > 0,
           !input.mobility.contains(.seatedOnly),
           let activity = catalog.activity(id: "tai_chi"),
           let met = activity.met.light {
            if budget >= 10 {
                let high = Int(min(15, budget))
                items.append(fixedItem(.balance, activity: activity, met: met, low: 10, high: high, input: input))
                budget -= Double(high)
            } else {
                noteLimitedByTime()
            }
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

    /// Minutes-only light plan while clinician clearance is pending: one 10–20 min item, within the daily budget
    /// and the session cap. Below 10 min of budget there is no item and `limitedByAvailableTime` is added.
    private static func clearancePlan(_ input: MovementPlanInput, catalog: METCatalog, budget: Double,
                                      sessionCap: Double, strengthGoal: Int, balanceGoal: Int) -> MovementPlan {
        var notices: [PlanNotice] = [.clinicianClearanceRecommended]
        var items: [PlanItem] = []
        let seated = input.mobility.contains(.seatedOnly)
        let activityId = seated ? "cycling_stationary" : "walking"
        if budget < Double(minimumSessionMinutes) {
            notices.append(.limitedByAvailableTime)
        } else if let activity = catalog.activity(id: activityId),
                  Set(activity.equipment).isSubset(of: input.equipment),
                  let met = activity.met.light {
            var high = Double(clearanceMaxMinutes)
            if sessionCap < high {
                high = sessionCap
                notices.append(.cappedAtSessionMaximum)
            }
            if budget < high {
                high = budget
                notices.append(.limitedByAvailableTime)
            }
            let low = min(Double(minimumSessionMinutes), high)
            items.append(PlanItem(kind: .aerobic, activityId: activity.id, intensity: Intensity.forMET(met), met: met,
                                  minutesLow: Int(low), minutesHigh: Int(high), kcal: nil))
        } else {
            notices.append(.noSuitableActivity)
        }
        return MovementPlan(
            items: items,
            weekly: WeeklyTargets(goalMinutes: whoBaseWeeklyMinutes, thisWeekMinutes: 0,
                                  strengthSessions: strengthGoal, balanceSessions: balanceGoal),
            notices: notices,
            rationale: [.whoPhysicalActivity2020]
        )
    }

    /// Column selection: when vigorous work is allowed, the vigorous column is used if its MET is >= 6;
    /// otherwise (or when not allowed) the first of the moderate / light columns below 6 MET. Nil when the
    /// activity has no usable column for the user. The label is always the MET band (`Intensity.forMET`),
    /// never the catalog column name, so the item is vigorous iff its MET is >= 6.
    private static func aerobicPrescription(for activity: ActivityType,
                                            allowVigorous: Bool) -> (intensity: Intensity, met: Double)? {
        if allowVigorous, let met = activity.met.vigorous, met >= 6 { return (Intensity.forMET(met), met) }
        for column in [Intensity.moderate, .light] {
            if let met = activity.met.value(for: column), met < 6 { return (Intensity.forMET(met), met) }
        }
        return nil
    }

    /// Preferred eligible activity first, then walking (aerobic) / bodyweight (strength), then catalog order.
    /// Aerobic activities are only eligible when they have a safe intensity for the user.
    private static func choose(_ category: ActivityCategory, input: MovementPlanInput, catalog: METCatalog,
                               requireLowImpact: Bool, allowVigorous: Bool) -> ActivityType? {
        let eligible = catalog.eligible(category: category, equipment: input.equipment,
                                        mobility: input.mobility, requireLowImpact: requireLowImpact)
            .filter { category != .aerobic || aerobicPrescription(for: $0, allowVigorous: allowVigorous) != nil }
        if let preferred = input.preferredActivityIds.lazy.compactMap({ id in eligible.first { $0.id == id } }).first {
            return preferred
        }
        let fallbackId = category == .aerobic ? "walking" : "strength_bodyweight"
        return eligible.first { $0.id == fallbackId } ?? eligible.first
    }

    /// `cap` is the smaller of the remaining budget and the session cap; neither bound can be exceeded.
    private static func makeItem(_ kind: PlanItemKind, activity: ActivityType, met: Double,
                                 minutes: Double, cap upper: Double, input: MovementPlanInput) -> PlanItem {
        let low = max(5, min(upper, roundTo(minutes * 0.9, step: 5)))
        let high = max(low, min(upper, roundTo(minutes * 1.1, step: 5)))
        return PlanItem(kind: kind, activityId: activity.id, intensity: Intensity.forMET(met), met: met,
                        minutesLow: Int(low), minutesHigh: Int(high),
                        kcal: kcalRange(met: met, low: low, estimate: minutes, high: high, input: input))
    }

    private static func fixedItem(_ kind: PlanItemKind, activity: ActivityType, met: Double,
                                  low: Int, high: Int, input: MovementPlanInput) -> PlanItem {
        PlanItem(kind: kind, activityId: activity.id, intensity: Intensity.forMET(met), met: met,
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
