import SwiftUI

/// An ad. Label first ("Ad · Partner" / "광고 · Partner"), solid neutral outline, a 44 pt "Why this ad" button.
/// Callers must never show this when numbers are hidden or next to totals.
public struct AdCard: View {
    private let label: Text
    private let title: Text
    private let subtitle: Text
    private let ctaTitle: Text
    private let onOpen: () -> Void
    private let onWhy: () -> Void

    public init(label: Text, title: Text, subtitle: Text, ctaTitle: Text, onOpen: @escaping () -> Void, onWhy: @escaping () -> Void) {
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.ctaTitle = ctaTitle
        self.onOpen = onOpen
        self.onWhy = onWhy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                label.font(.nuriFootnoteEmphasis).foregroundStyle(Color.nuriAdLabel)
                Spacer()
                Button(action: onWhy) { Image(systemName: "info.circle") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.nuriInkSoft)
                    .frame(width: NuriMetrics.minTouch, height: NuriMetrics.minTouch)
                    .accessibilityLabel(Text("Why this ad, and hide options", bundle: .module))
            }
            title.font(.nuriHeadline).foregroundStyle(Color.nuriInk)
            subtitle.font(.nuriFootnote).foregroundStyle(Color.nuriInkSoft)
            Button(action: onOpen) {
                HStack(spacing: 6) { ctaTitle; Image(systemName: "arrow.up.right.square").accessibilityHidden(true) }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NuriSecondaryButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.nuriSurface, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NuriMetrics.radiusCard, style: .continuous).strokeBorder(Color.nuriAdOutline, lineWidth: 1.5))
    }
}
