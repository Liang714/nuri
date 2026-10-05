public struct NutrientProfile: Codable, Sendable, Equatable {
    public var energyKcal: Double
    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?
    public var fiberG: Double?
    public var sugarG: Double?
    public var saturatedFatG: Double?
    public var sodiumMg: Double?
    /// Optional micronutrients keyed by "<name>_<unit>", e.g. "iron_mg", "vitamin_d_ug".
    public var micronutrients: [String: Double]

    public init(energyKcal: Double, proteinG: Double? = nil, carbsG: Double? = nil, fatG: Double? = nil,
                fiberG: Double? = nil, sugarG: Double? = nil, saturatedFatG: Double? = nil,
                sodiumMg: Double? = nil, micronutrients: [String: Double] = [:]) {
        self.energyKcal = energyKcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.saturatedFatG = saturatedFatG
        self.sodiumMg = sodiumMg
        self.micronutrients = micronutrients
    }

    public static let zero = NutrientProfile(energyKcal: 0)

    public func scaled(by factor: Double) -> NutrientProfile {
        NutrientProfile(
            energyKcal: energyKcal * factor,
            proteinG: proteinG.map { $0 * factor },
            carbsG: carbsG.map { $0 * factor },
            fatG: fatG.map { $0 * factor },
            fiberG: fiberG.map { $0 * factor },
            sugarG: sugarG.map { $0 * factor },
            saturatedFatG: saturatedFatG.map { $0 * factor },
            sodiumMg: sodiumMg.map { $0 * factor },
            micronutrients: micronutrients.mapValues { $0 * factor }
        )
    }

    public static func + (lhs: NutrientProfile, rhs: NutrientProfile) -> NutrientProfile {
        func add(_ a: Double?, _ b: Double?) -> Double? {
            if a == nil && b == nil { return nil }
            return (a ?? 0) + (b ?? 0)
        }
        return NutrientProfile(
            energyKcal: lhs.energyKcal + rhs.energyKcal,
            proteinG: add(lhs.proteinG, rhs.proteinG),
            carbsG: add(lhs.carbsG, rhs.carbsG),
            fatG: add(lhs.fatG, rhs.fatG),
            fiberG: add(lhs.fiberG, rhs.fiberG),
            sugarG: add(lhs.sugarG, rhs.sugarG),
            saturatedFatG: add(lhs.saturatedFatG, rhs.saturatedFatG),
            sodiumMg: add(lhs.sodiumMg, rhs.sodiumMg),
            micronutrients: lhs.micronutrients.merging(rhs.micronutrients, uniquingKeysWith: +)
        )
    }
}

public enum NutritionMath {
    public static func nutrients(per100g: NutrientProfile, grams: Double) -> NutrientProfile {
        per100g.scaled(by: grams / 100)
    }
}

/// Flags records whose stated energy disagrees with Atwater general factors (4/4/9 kcal/g).
/// Tolerance is wide (max of 20 kcal or 20%) because labels round and fiber, alcohol and polyols differ.
public enum EnergyConsistency {
    public enum Result: Equatable, Sendable {
        case consistent
        case inconsistent(statedKcal: Double, computedKcal: Double)
        case insufficientData
    }

    public static func check(_ p: NutrientProfile) -> Result {
        guard let protein = p.proteinG, let carbs = p.carbsG, let fat = p.fatG else { return .insufficientData }
        let computed = 4 * protein + 4 * carbs + 9 * fat
        let tolerance = max(20, 0.2 * max(p.energyKcal, computed))
        return abs(p.energyKcal - computed) <= tolerance
            ? .consistent
            : .inconsistent(statedKcal: p.energyKcal, computedKcal: computed)
    }
}
