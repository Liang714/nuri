/// Where a food's numbers come from. Raw values are persisted and must never change.
public enum FoodSource: String, CaseIterable, Codable, Sendable {
    case verified, manufacturer, community, userCreated, photoEstimate
}
