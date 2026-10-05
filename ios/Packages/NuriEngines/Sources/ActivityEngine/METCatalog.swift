import Foundation

public enum Intensity: String, Codable, Sendable, CaseIterable {
    case light, moderate, vigorous

    /// MET band (WHO 2020 / Compendium): < 3 light, 3 to < 6 moderate, >= 6 vigorous.
    /// Every intensity label the engines return is derived from the item's MET with this function,
    /// whichever catalog column the MET came from.
    public static func forMET(_ met: Double) -> Intensity {
        if met >= 6 { return .vigorous }
        return met >= 3 ? .moderate : .light
    }
}

public enum ActivityCategory: String, Codable, Sendable, CaseIterable {
    case aerobic, strength, balance, flexibility
}

public enum MobilityPreference: String, Codable, Sendable, CaseIterable {
    case lowImpactOnly, seatedOnly
}

public struct METValues: Codable, Sendable, Equatable {
    public let light: Double?
    public let moderate: Double?
    public let vigorous: Double?

    public func value(for intensity: Intensity) -> Double? {
        switch intensity {
        case .light: light
        case .moderate: moderate
        case .vigorous: vigorous
        }
    }
}

public struct ActivityType: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let category: ActivityCategory
    public let met: METValues
    public let equipment: [String]
    public let tags: [String]

    public var isLowImpact: Bool { tags.contains("low_impact") }
    public var isSeated: Bool { tags.contains("seated") }
}

public enum METCatalogError: Error, Equatable, Sendable {
    case resourceMissing
}

public struct METCatalog: Codable, Sendable, Equatable {
    public let version: String
    public let sourceReference: String
    public let activities: [ActivityType]

    public init(version: String, sourceReference: String, activities: [ActivityType]) {
        self.version = version
        self.sourceReference = sourceReference
        self.activities = activities
    }

    public static func bundled() throws -> METCatalog {
        guard let url = Bundle.module.url(forResource: "met-catalog", withExtension: "json") else {
            throw METCatalogError.resourceMissing
        }
        return try JSONDecoder().decode(METCatalog.self, from: Data(contentsOf: url))
    }

    public func activity(id: String) -> ActivityType? {
        activities.first { $0.id == id }
    }

    /// Activities the user can do with their equipment and mobility profile, in catalog order.
    public func eligible(category: ActivityCategory?, equipment: Set<String>,
                         mobility: Set<MobilityPreference>, requireLowImpact: Bool) -> [ActivityType] {
        activities.filter { a in
            (category == nil || a.category == category)
                && Set(a.equipment).isSubset(of: equipment)
                && (!mobility.contains(.seatedOnly) || a.isSeated)
                && (!(mobility.contains(.lowImpactOnly) || requireLowImpact) || a.isLowImpact)
        }
    }
}
