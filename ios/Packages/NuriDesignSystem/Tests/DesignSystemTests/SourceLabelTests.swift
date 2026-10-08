import Testing
@testable import DesignSystem

@Suite struct SourceLabelTests {
    @Test(arguments: SourceKind.allCases)
    func everyKindHasSymbolAndReadableColor(kind: SourceKind) {
        #expect(!kind.symbolName.isEmpty)
        #expect(Contrast.ratio(kind.color.light, NuriPalette.surface.light) >= 4.5)
        #expect(Contrast.ratio(kind.color.dark, NuriPalette.surface.dark) >= 4.5)
    }
}
