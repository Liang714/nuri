import SwiftUI

/// A gentle notice (e.g. clinician suggestion, feature not ready yet). Never alarming.
public struct NoticeCard: View {
    private let title: Text
    private let message: Text
    private let actionTitle: Text?
    private let action: (() -> Void)?

    public init(title: Text, message: Text, actionTitle: Text? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart").font(.nuriHeadline).foregroundStyle(Color.nuriNoticeInk).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    title.font(.nuriSubheadlineEmphasis)
                    message.font(.nuriFootnote)
                }
                .accessibilityElement(children: .combine)
                if let actionTitle, let action {
                    Button(action: action) { actionTitle }
                        .buttonStyle(.plain)
                        .font(.nuriFootnoteEmphasis)
                        .foregroundStyle(Color.nuriLink)
                        .frame(minHeight: NuriMetrics.minTouch, alignment: .leading)
                }
            }
            .foregroundStyle(Color.nuriNoticeInk)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.nuriNotice, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusCard, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
