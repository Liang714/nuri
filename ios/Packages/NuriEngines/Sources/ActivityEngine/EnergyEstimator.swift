public struct EnergyRange: Equatable, Sendable {
    public let low: Double
    public let estimate: Double
    public let high: Double

    public init(low: Double, estimate: Double, high: Double) {
        self.low = low
        self.estimate = estimate
        self.high = high
    }
}

public enum EnergyEstimator {
    public static let lowFactor = 0.80
    public static let highFactor = 1.25

    /// kcal = MET × body mass (kg) × duration (h).
    public static func kcal(met: Double, weightKg: Double, minutes: Double) -> Double {
        met * weightKg * minutes / 60
    }

    public static func kcalRange(met: Double, weightKg: Double, minutes: Double) -> EnergyRange {
        let e = kcal(met: met, weightKg: weightKg, minutes: minutes)
        return EnergyRange(low: e * lowFactor, estimate: e, high: e * highFactor)
    }
}
