import NuriDomain

public enum ExerciseCreditMode: Codable, Sendable, Equatable {
    case baseTargetOnly
    case partialCredit(percent: Double)
    case fullCredit
    case noEnergyMath

    /// Spec §5.5: expenditure estimates are imprecise and baseline activity is already in TDEE.
    public static let `default` = ExerciseCreditMode.baseTargetOnly
}

/// The daily "ledger" is always shown as separate lines, never as a single net-calories number.
public struct DailyLedger: Equatable, Sendable {
    public let foodKcal: Double
    public let activityKcalBySource: [ActivityEnergySource: Double]
    public let totalActivityKcal: Double
    public let baseTargetKcal: Double?
    public let creditedActivityKcal: Double
    public let adjustedTargetKcal: Double?
    /// Planning amount left. Nil without a target or in `.noEnergyMath`.
    public let remainingKcal: Double?

    public static func compute(foodKcal: Double, activityKcalBySource: [ActivityEnergySource: Double],
                               baseTargetKcal: Double?, mode: ExerciseCreditMode) -> DailyLedger {
        let totalActivity = activityKcalBySource.values.reduce(0, +)
        let credited: Double = switch mode {
        case .baseTargetOnly, .noEnergyMath: 0
        case .partialCredit(let percent): totalActivity * min(100, max(0, percent)) / 100
        case .fullCredit: totalActivity
        }
        let adjusted: Double? = (mode == .noEnergyMath) ? nil : baseTargetKcal.map { $0 + credited }
        return DailyLedger(
            foodKcal: foodKcal,
            activityKcalBySource: activityKcalBySource,
            totalActivityKcal: totalActivity,
            baseTargetKcal: baseTargetKcal,
            creditedActivityKcal: credited,
            adjustedTargetKcal: adjusted,
            remainingKcal: adjusted.map { $0 - foodKcal }
        )
    }
}
