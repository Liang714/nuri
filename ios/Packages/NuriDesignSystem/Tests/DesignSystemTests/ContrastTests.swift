import Testing
@testable import DesignSystem

@Suite struct ContrastTests {
    @Test func whiteOnBlackIs21() {
        #expect(abs(Contrast.ratio(RGB(hex: 0xFFFFFF), RGB(hex: 0x000000)) - 21) < 0.01)
    }

    @Test func sameColorIs1() {
        #expect(Contrast.ratio(RGB(hex: 0x3B6A4A), RGB(hex: 0x3B6A4A)) == 1)
    }

    @Test func orderDoesNotMatter() {
        let a = RGB(hex: 0x4A5750), b = RGB(hex: 0xF2F4EF)
        #expect(Contrast.ratio(a, b) == Contrast.ratio(b, a))
    }

    @Test func knownPairMatchesReference() {
        // #4A5750 on #FFFFFF ≈ 7.58 (computed with the WCAG 2.x formula)
        #expect(abs(Contrast.ratio(RGB(hex: 0x4A5750), RGB(hex: 0xFFFFFF)) - 7.58) < 0.05)
    }

    @Test func hexChannels() {
        let c = RGB(hex: 0x336699)
        #expect(abs(c.red - 0.2) < 0.001 && abs(c.green - 0.4) < 0.001 && abs(c.blue - 0.6) < 0.001)
    }
}
