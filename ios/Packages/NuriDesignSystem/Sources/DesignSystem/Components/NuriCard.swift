import SwiftUI

/// The white grouped surface used for lists and summaries.
public struct NuriCard<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.nuriSurface, in: RoundedRectangle(cornerRadius: NuriMetrics.radiusCard, style: .continuous))
    }
}
