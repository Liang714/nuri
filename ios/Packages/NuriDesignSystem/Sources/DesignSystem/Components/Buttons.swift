import SwiftUI

public struct NuriPrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { PrimaryBody(configuration: configuration) }

    private struct PrimaryBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.nuriHeadline)
                .foregroundStyle(isEnabled ? Color.nuriOnTint : Color.nuriDisabledText)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: NuriMetrics.buttonHeight)
                .padding(.horizontal, 16)
                .background(background, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
        }
        private var background: Color {
            guard isEnabled else { return .nuriDisabledFill }
            return configuration.isPressed ? .nuriTintPressed : .nuriTint
        }
    }
}

/// A quiet filled button. At least 44 pt tall; pass `minHeight: NuriMetrics.buttonHeight` to sit beside a primary
/// button. Passing `minWidth` makes an icon-only tile of that minimum size (no horizontal padding).
public struct NuriSecondaryButtonStyle: ButtonStyle {
    private let minWidth: CGFloat?
    private let minHeight: CGFloat

    public init(minWidth: CGFloat? = nil, minHeight: CGFloat = NuriMetrics.minTouch) {
        self.minWidth = minWidth
        self.minHeight = minHeight
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nuriSubheadlineEmphasis)
            .foregroundStyle(Color.nuriInk)
            .frame(minWidth: minWidth, minHeight: minHeight)
            .padding(.horizontal, minWidth == nil ? 16 : 0)
            .background(Color.nuriFillSecondary.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: NuriMetrics.radiusControl, style: .continuous))
            .contentShape(Rectangle())
    }
}

public struct NuriTextButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nuriSubheadlineEmphasis)
            .foregroundStyle(Color.nuriTint.opacity(configuration.isPressed ? 0.6 : 1))
            .frame(minWidth: NuriMetrics.minTouch, minHeight: NuriMetrics.minTouch)
            .contentShape(Rectangle())
    }
}
