/// Where an activity energy value came from. Shown to users as a source label.
public enum ActivityEnergySource: String, Codable, Sendable, CaseIterable {
    case manualMET, wearable, healthPlatform, custom
}
