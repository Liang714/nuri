import SwiftUI

public extension View {
    /// Secondary copy: footnote size in `nuriInkSoft`.
    ///
    /// SwiftUI's own secondary style is system gray, about 3.3:1 on the Nuri ground, below the 4.5:1 text rule.
    /// Use this (or `nuriInkSoft` directly) for list footers, detail lines and other quiet text.
    func nuriSecondaryText() -> some View {
        font(.nuriFootnote).foregroundStyle(Color.nuriInkSoft)
    }

    /// An inset-grouped list on the Nuri ground: system background hidden, rows set with `listRowBackground(Color.nuriSurface)`.
    func nuriGroupedList() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nuriGround.ignoresSafeArea())
        #else
        scrollContentBackground(.hidden)
            .background(Color.nuriGround.ignoresSafeArea())
        #endif
    }
}

/// A list section header in `nuriInkSoft` at footnote emphasis (the system default is a lighter gray).
public struct NuriSectionHeader: View {
    private let text: Text

    public init(_ text: Text) { self.text = text }

    public var body: some View {
        text.font(.nuriFootnoteEmphasis).foregroundStyle(Color.nuriInkSoft)
    }
}
