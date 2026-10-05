import Foundation

/// WHO (2000) adult cutoffs, or WHO Western Pacific (2000) / Korean Society for the Study of Obesity cutoffs.
public enum BMIStandard: String, Codable, Sendable, CaseIterable {
    case who, asianPacific

    static let asianPacificRegions: Set<String> = [
        "KR", "JP", "CN", "TW", "HK", "MO", "SG", "MY", "TH", "VN", "PH", "ID", "MN",
    ]

    /// Default by App Store / device region; the user can override in Settings.
    public static func defaultStandard(forRegion code: String?) -> BMIStandard {
        guard let code else { return .who }
        return asianPacificRegions.contains(code.uppercased()) ? .asianPacific : .who
    }
}

public enum BMICategory: String, Codable, Sendable, CaseIterable {
    case underweight, normal, overweight, obese
}

public enum BMI {
    /// Below this BMI is underweight in both standards (WHO 2000). Shared by `category(for:standard:)`,
    /// the energy-target loss block and the movement plan.
    public static let underweightCutoff = 18.5

    public static func value(weightKg: Double, heightCm: Double) -> Double {
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    public static func category(for bmi: Double, standard: BMIStandard) -> BMICategory {
        if bmi < underweightCutoff { return .underweight }
        switch standard {
        case .who:
            if bmi < 25 { return .normal }
            return bmi < 30 ? .overweight : .obese
        case .asianPacific:
            if bmi < 23 { return .normal }
            return bmi < 25 ? .overweight : .obese
        }
    }
}
