public enum ServingUnit: String, Codable, Sendable, CaseIterable {
    case gram, ounce, milliliter, cup, tablespoon, teaspoon, piece, slice, package, serving
}

/// A food-specific serving with its gram weight. Volume units always need one (no assumed density).
public struct ServingOption: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let unit: ServingUnit
    public let label: String?
    public let gramsPerUnit: Double

    public init(id: String, unit: ServingUnit, label: String?, gramsPerUnit: Double) {
        self.id = id
        self.unit = unit
        self.label = label
        self.gramsPerUnit = gramsPerUnit
    }
}

public enum ServingConversionError: Error, Equatable, Sendable {
    case nonPositiveQuantity
    case missingGramWeight(ServingUnit)
}

public enum ServingConverter {
    public static let gramsPerOunce = 28.349523125

    public static func grams(quantity: Double, unit: ServingUnit,
                             options: [ServingOption]) throws(ServingConversionError) -> Double {
        guard quantity.isFinite, quantity > 0 else { throw .nonPositiveQuantity }
        switch unit {
        case .gram:
            return quantity
        case .ounce:
            return quantity * gramsPerOunce
        default:
            guard let option = options.first(where: { $0.unit == unit }) else { throw .missingGramWeight(unit) }
            return quantity * option.gramsPerUnit
        }
    }
}
