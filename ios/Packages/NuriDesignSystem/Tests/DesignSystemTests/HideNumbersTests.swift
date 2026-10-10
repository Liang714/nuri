import SwiftUI
import Testing
@testable import DesignSystem

@MainActor
@Suite struct HideNumbersTests {
    private func renderedSize(_ view: some View) -> CGSize? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.cgImage.map { CGSize(width: $0.width, height: $0.height) }
    }

    private var ad: AdCard {
        AdCard(label: Text(verbatim: "Ad · Partner"), title: Text(verbatim: "Title"), subtitle: Text(verbatim: "Subtitle"),
               ctaTitle: Text(verbatim: "Open"), onOpen: {}, onWhy: {})
    }

    @Test func hideNumbersIsOffByDefault() {
        #expect(EnvironmentValues().nuriHideNumbers == false)
    }

    @Test func adCardRendersNothingWhenNumbersAreHidden() {
        #expect(renderedSize(ad.environment(\.nuriHideNumbers, true)) == nil)
    }

    @Test func adCardRendersWhenNumbersAreShown() {
        #expect(renderedSize(ad.environment(\.nuriHideNumbers, false)) != nil)
    }

    @Test func progressBarSpeaksItsValueOnlyWhenNumbersAreShown() {
        #expect(NuriProgressBar.spokenValue(Text(verbatim: "1,240 of 2,000"), hideNumbers: false) != nil)
        #expect(NuriProgressBar.spokenValue(Text(verbatim: "1,240 of 2,000"), hideNumbers: true) == nil)
    }
}
