import NutritionEngine

public struct EquivalentsInput: Sendable {
    public var targetKcal: Double
    public var weightKg: Double?
    public var preferredActivityIds: [String]
    public var availableMinutes: Int?
    public var equipment: Set<String>
    public var mobility: Set<MobilityPreference>
    public var sensitiveMode: Bool
    public var enabled: Bool
    public var maxSessionMinutes: Int

    public init(targetKcal: Double, weightKg: Double?, preferredActivityIds: [String], availableMinutes: Int?,
                equipment: Set<String>, mobility: Set<MobilityPreference>, sensitiveMode: Bool, enabled: Bool,
                maxSessionMinutes: Int = 60) {
        self.targetKcal = targetKcal
        self.weightKg = weightKg
        self.preferredActivityIds = preferredActivityIds
        self.availableMinutes = availableMinutes
        self.equipment = equipment
        self.mobility = mobility
        self.sensitiveMode = sensitiveMode
        self.enabled = enabled
        self.maxSessionMinutes = maxSessionMinutes
    }
}

public struct EquivalentOption: Equatable, Sendable {
    public let activityId: String
    public let intensity: Intensity
    public let met: Double
    public let minutesLow: Int
    public let minutesHigh: Int
    /// True when the upper bound exceeds 90 minutes; the UI shows "90+ min".
    public let highIsOpenEnded: Bool
    /// True when the range exceeds the session cap; the UI offers "split across the day".
    public let suggestSplitting: Bool
}

public enum EquivalentsResult: Equatable, Sendable {
    public enum SuppressionReason: Equatable, Sendable {
        case disabled, sensitiveMode, missingWeight, invalidTarget, noEligibleActivities
    }
    case suppressed(SuppressionReason)
    case options([EquivalentOption])
}

/// Educational, opt-in estimates. Never a requirement to offset food (spec §5.6).
public enum ActivityEquivalents {
    public static let maxOptions = 5

    /// < 30 min → nearest 5 (minimum 5); 30–90 → nearest 10; > 90 → 90 and open-ended.
    public static func practicalMinutes(_ minutes: Double) -> (minutes: Int, openEnded: Bool) {
        if minutes > 90 { return (90, true) }
        if minutes < 30 { return (max(5, Int(roundTo(minutes, step: 5))), false) }
        return (Int(roundTo(minutes, step: 10)), false)
    }

    /// Recommends activities matched to target energy expenditure.
    /// MET column: the catalog moderate value, falling back to light; the vigorous column is never used.
    /// The `intensity` label is the MET band (`Intensity.forMET`), so a moderate column of 6 MET or more
    /// (running 8.3, cycling 6.8) is labelled vigorous.
    /// Ranking (spec §5.6 rules 3 and 5): preferred (user order) → fits the available time
    /// (minimum duration <= available minutes; everything fits when none is given) → non-vigorous before
    /// vigorous → shorter minimum duration → id. Options that exceed the session cap or the user's available
    /// time get `suggestSplitting`. Walking is always included if eligible.
    /// Returns `.suppressed(.noEligibleActivities)` if no activities match constraints.
    public static func recommend(_ input: EquivalentsInput, catalog: METCatalog) -> EquivalentsResult {
        guard input.enabled else { return .suppressed(.disabled) }
        guard !input.sensitiveMode else { return .suppressed(.sensitiveMode) }
        guard let weight = input.weightKg, weight > 0 else { return .suppressed(.missingWeight) }
        guard input.targetKcal.isFinite, input.targetKcal > 0, input.targetKcal <= 5000 else {
            return .suppressed(.invalidTarget)
        }

        let candidates = catalog.eligible(category: nil, equipment: input.equipment,
                                          mobility: input.mobility, requireLowImpact: false)
            .filter { $0.category == .aerobic || $0.category == .strength }

        let options: [EquivalentOption] = candidates.compactMap { activity in
            // Moderate column, falling back to light; never the vigorous column. The label is the MET band.
            guard let met = activity.met.moderate ?? activity.met.light else { return nil }
            let intensity = Intensity.forMET(met)
            let minutes = input.targetKcal / (met * weight) * 60
            let low = practicalMinutes(minutes * EnergyEstimator.lowFactor)
            let high = practicalMinutes(minutes * EnergyEstimator.highFactor)
            return EquivalentOption(
                activityId: activity.id, intensity: intensity, met: met,
                minutesLow: low.minutes, minutesHigh: high.minutes, highIsOpenEnded: high.openEnded,
                suggestSplitting: high.openEnded || high.minutes > input.maxSessionMinutes
                    || input.availableMinutes.map { low.minutes > $0 } ?? false
            )
        }

        func sortKey(_ o: EquivalentOption) -> (Int, Int, Int, Int, String) {
            let preferenceRank = input.preferredActivityIds.firstIndex(of: o.activityId) ?? Int.max
            let fitsAvailable = input.availableMinutes.map { o.minutesLow <= $0 } ?? true
            return (preferenceRank, fitsAvailable ? 0 : 1, o.intensity == .vigorous ? 1 : 0, o.minutesLow, o.activityId)
        }
        let ranked = options.sorted { sortKey($0) < sortKey($1) }

        var top = Array(ranked.prefix(maxOptions))
        if !top.contains(where: { $0.activityId == "walking" }),
           let walking = ranked.first(where: { $0.activityId == "walking" }) {
            if top.count == maxOptions { top.removeLast() }
            top.append(walking)
        }
        guard !top.isEmpty else { return .suppressed(.noEligibleActivities) }
        return .options(top)
    }
}
