import SwiftUI

/// iOS text styles in SF Pro Rounded; all scale with Dynamic Type.
public extension Font {
    static let nuriLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let nuriTitle = Font.system(.title, design: .rounded, weight: .bold)
    static let nuriTitle2 = Font.system(.title2, design: .rounded, weight: .bold)
    static let nuriHeadline = Font.system(.headline, design: .rounded, weight: .bold)
    static let nuriBody = Font.system(.body, design: .rounded)
    static let nuriBodyEmphasis = Font.system(.body, design: .rounded, weight: .semibold)
    static let nuriSubheadline = Font.system(.subheadline, design: .rounded)
    static let nuriSubheadlineEmphasis = Font.system(.subheadline, design: .rounded, weight: .semibold)
    static let nuriFootnote = Font.system(.footnote, design: .rounded)
    static let nuriFootnoteEmphasis = Font.system(.footnote, design: .rounded, weight: .bold)
    static let nuriCaption = Font.system(.caption, design: .rounded)
}
