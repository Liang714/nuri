/// The six food groups that make up a person's world. Their colors are reserved for the world and its legend.
public enum FoodGroup: String, CaseIterable, Codable, Sendable {
    case vegetables, fruit, grains, protein, legumesAndNuts, dairyAndAlternatives

    public var fill: RGB {
        switch self {
        case .vegetables: RGB(hex: 0x4F8A5B)
        case .fruit: RGB(hex: 0xD07A9A)
        case .grains: RGB(hex: 0xE2B54E)
        case .protein: RGB(hex: 0x7E4127)
        case .legumesAndNuts: RGB(hex: 0x8B7AC0)
        case .dairyAndAlternatives: RGB(hex: 0xF6F3EA)
        }
    }

    /// Ring that separates a place from the globe and its neighbors (≥3:1 against the globe in both themes).
    public var ring: ThemedColor {
        switch self {
        case .vegetables: ThemedColor(light: 0x2F5A39, dark: 0xA9D3B4)
        case .fruit: ThemedColor(light: 0x8E4766, dark: 0xF2B8CD)
        case .grains: ThemedColor(light: 0x8A6A1E, dark: 0xF4D78F)
        case .protein: ThemedColor(light: 0x4A2414, dark: 0xE0A88A)
        case .legumesAndNuts: ThemedColor(light: 0x5E4F94, dark: 0xC5BAE8)
        case .dairyAndAlternatives: ThemedColor(light: 0x7D7563, dark: 0xF6F3EA)
        }
    }
}

public enum WorldPalette {
    public static let globe = ThemedColor(light: 0xDCE9F1, dark: 0x22313A)
    /// Separator stroke drawn behind a filled place. White on light; in dark it blends with the globe instead of glaring.
    public static let halo = ThemedColor(light: 0xFFFFFF, dark: 0x22313A)
}
