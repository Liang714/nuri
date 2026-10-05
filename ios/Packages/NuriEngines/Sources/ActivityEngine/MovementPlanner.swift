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
}
