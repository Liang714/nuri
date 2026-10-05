/// Sex value used only by energy equations that require it (Mifflin-St Jeor). Optional for users.
public enum SexForEquation: String, Codable, Sendable, CaseIterable {
    case male, female
}

public enum ActivityLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case sedentary, lightlyActive, moderatelyActive, veryActive, extraActive

    public var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }

    private var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

public enum Goal: String, Codable, Sendable, CaseIterable {
    case maintain, gradualLoss, gradualGain, improveNutrition, performance, trackOnly
}

public enum ProfileValidationError: Error, Equatable, Sendable {
    case ageOutOfRange(Int)
    case heightOutOfRange(Double)
    case weightOutOfRange(Double)
}

public struct BodyProfile: Codable, Sendable, Equatable {
    public static let ageRange = 18...120
    public static let heightRangeCm = 100.0...250.0
    public static let weightRangeKg = 30.0...350.0

    public var ageYears: Int
    public var sex: SexForEquation?
    public var heightCm: Double
    public var weightKg: Double
    public var activityLevel: ActivityLevel
    public var goal: Goal

    public init(ageYears: Int, sex: SexForEquation?, heightCm: Double, weightKg: Double,
                activityLevel: ActivityLevel, goal: Goal) {
        self.ageYears = ageYears
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
    }

    public func validated() throws(ProfileValidationError) -> BodyProfile {
        guard Self.ageRange.contains(ageYears) else { throw .ageOutOfRange(ageYears) }
        guard Self.heightRangeCm.contains(heightCm) else { throw .heightOutOfRange(heightCm) }
        guard Self.weightRangeKg.contains(weightKg) else { throw .weightOutOfRange(weightKg) }
        return self
    }
}
