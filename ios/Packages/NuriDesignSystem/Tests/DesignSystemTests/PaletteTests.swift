import Testing
@testable import DesignSystem

@Suite struct PaletteTests {
    typealias P = NuriPalette

    // (foreground, background, label) — text must reach 4.5:1 in light AND dark
    static let textPairs: [(ThemedColor, ThemedColor, String)] = [
        (P.ink, P.ground, "ink/ground"), (P.ink, P.surface, "ink/surface"),
        (P.inkSoft, P.ground, "inkSoft/ground"), (P.inkSoft, P.surface, "inkSoft/surface"),
        (P.ink, P.fillSecondary, "ink/fillSecondary"), (P.inkSoft, P.fillSecondary, "inkSoft/fillSecondary"),
        (P.onTint, P.tint, "onTint/tint"), (P.onTint, P.tintPressed, "onTint/tintPressed"),
        (P.tint, P.surface, "tint/surface"), (P.tint, P.ground, "tint/ground"),
        (P.link, P.surface, "link/surface"), (P.link, P.ground, "link/ground"), (P.link, P.notice, "link/notice"),
        (P.verified, P.surface, "verified/surface"), (P.manufacturer, P.surface, "manufacturer/surface"),
        (P.community, P.surface, "community/surface"), (P.adLabel, P.surface, "adLabel/surface"),
        (P.noticeInk, P.notice, "noticeInk/notice"), (P.onToast, P.toast, "onToast/toast"),
        (P.toastAction, P.toast, "toastAction/toast"), (P.disabledText, P.disabledFill, "disabledText/disabledFill"),
    ]

    // non-text UI parts must reach 3:1
    static let partPairs: [(ThemedColor, ThemedColor, String)] = [
        (P.progress, P.track, "progress/track"), (P.progress, P.surface, "progress/surface"),
        (P.adOutline, P.surface, "adOutline/surface"), (P.adOutline, P.ground, "adOutline/ground"),
        (P.chevron, P.surface, "chevron/surface"),
    ]

    @Test(arguments: textPairs.indices)
    func textContrast(index: Int) {
        let (fg, bg, label) = Self.textPairs[index]
        #expect(Contrast.ratio(fg.light, bg.light) >= 4.5, "\(label) light")
        #expect(Contrast.ratio(fg.dark, bg.dark) >= 4.5, "\(label) dark")
    }

    @Test(arguments: partPairs.indices)
    func partContrast(index: Int) {
        let (fg, bg, label) = Self.partPairs[index]
        #expect(Contrast.ratio(fg.light, bg.light) >= 3, "\(label) light")
        #expect(Contrast.ratio(fg.dark, bg.dark) >= 3, "\(label) dark")
    }

    @Test func approvedHexValues() {
        #expect(P.ground.light == RGB(hex: 0xF2F4EF) && P.ground.dark == RGB(hex: 0x121714))
        #expect(P.tint.light == RGB(hex: 0x3B6A4A) && P.tint.dark == RGB(hex: 0x7FB58A))
        #expect(P.progress.light == RGB(hex: 0x4A82AB) && P.progress.dark == RGB(hex: 0x7EB0D6))
    }
}
