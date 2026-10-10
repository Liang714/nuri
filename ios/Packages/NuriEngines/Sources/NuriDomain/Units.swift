/// How the person prefers to see height and weight. Engines always work in centimeters and kilograms.
public enum UnitSystem: String, CaseIterable, Codable, Sendable {
    case metric, imperial

    public static func defaultFor(regionCode: String?) -> UnitSystem {
        guard let code = regionCode?.uppercased() else { return .metric }
        return ["US", "LR", "MM"].contains(code) ? .imperial : .metric
    }
}

public enum BodyUnits {
    public static let centimetersPerInch = 2.54
    public static let kilogramsPerPound = 0.45359237

    public static func cm(feet: Int, inches: Int) -> Double { Double(feet * 12 + inches) * centimetersPerInch }

    /// Whole feet and inches, rounded to the nearest inch. A value that is not a height (NaN, infinite, zero, negative
    /// or too large to count in inches) gives (0, 0) instead of trapping.
    public static func feetAndInches(cm: Double) -> (feet: Int, inches: Int) {
        guard cm.isFinite, cm > 0, let totalInches = Int(exactly: (cm / centimetersPerInch).rounded()) else { return (0, 0) }
        return (totalInches / 12, totalInches % 12)
    }

    public static func kg(pounds: Double) -> Double { pounds * kilogramsPerPound }
    public static func pounds(kg: Double) -> Double { kg / kilogramsPerPound }
}
