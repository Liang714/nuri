import SwiftUI
import NuriDomain

/// Existing name for the food-source enum, which now lives in NuriDomain.
public typealias SourceKind = FoodSource

extension FoodSource {
    public var symbolName: String {
        switch self {
        case .verified: "checkmark.shield"
        case .manufacturer: "building.2"
        case .community: "person.2"
        case .userCreated: "person"
        case .photoEstimate: "camera"
        }
    }

    public var color: ThemedColor {
        switch self {
        case .verified: NuriPalette.verified
        case .manufacturer: NuriPalette.manufacturer
        case .community: NuriPalette.community
        case .userCreated, .photoEstimate: NuriPalette.inkSoft
        }
    }
}

/// Where a food's numbers come from. Icon + text, never color alone.
public struct SourceLabel: View {
    private let kind: FoodSource
    private let title: Text
    private let spoken: Text

    public init(_ kind: FoodSource, title: Text, accessibilityLabel: Text) {
        self.kind = kind
        self.title = title
        self.spoken = accessibilityLabel
    }

    public var body: some View {
        Label { title } icon: { Image(systemName: kind.symbolName) }
            .labelStyle(.titleAndIcon)
            .font(.nuriFootnoteEmphasis)
            .foregroundStyle(Color(kind.color))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
    }
}
