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

public struct NuriSecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nuriSubheadlineEmphasis)
            .foregroundStyle(Color.nuriInk)
            .frame(minHeight: NuriMetrics.minTouch)
            .padding(.horizontal, 16)
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
            .frame(minHeight: NuriMetrics.minTouch)
            .contentShape(Rectangle())
    }
}
