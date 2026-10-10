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

    public static func feetAndInches(cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = Int((cm / centimetersPerInch).rounded())
        return (totalInches / 12, totalInches % 12)
    }

    public static func kg(pounds: Double) -> Double { pounds * kilogramsPerPound }
    public static func pounds(kg: Double) -> Double { kg / kilogramsPerPound }
}
