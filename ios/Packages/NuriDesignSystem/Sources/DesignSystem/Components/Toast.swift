import SwiftUI

/// Confirmation with an undo, e.g. "Added to lunch · Undo".
public struct NuriToast: View {
    private let message: Text
    private let actionTitle: Text
    private let action: () -> Void

    public init(message: Text, actionTitle: Text, action: @escaping () -> Void) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.nuriToastAction).accessibilityHidden(true)
            message.font(.nuriSubheadlineEmphasis).foregroundStyle(Color.nuriOnToast)
            Spacer(minLength: 8)
            Button(action: action) { actionTitle }
                .buttonStyle(.plain)
                .font(.nuriSubheadlineEmphasis)
                .foregroundStyle(Color.nuriToastAction)
                .frame(minWidth: NuriMetrics.minTouch, minHeight: NuriMetrics.minTouch)
        }
        .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 4)
        .background(Color.nuriToast, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusButton, style: .continuous))
    }
}
