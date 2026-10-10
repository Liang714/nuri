import Testing
import NuriDomain
@testable import DesignSystem

@Suite struct SourceLabelTests {
    @Test(arguments: FoodSource.allCases)
    func everyKindHasSymbolAndReadableColor(kind: FoodSource) {
        #expect(!kind.symbolName.isEmpty)
        #expect(Contrast.ratio(kind.color.light, NuriPalette.surface.light) >= 4.5)
        #expect(Contrast.ratio(kind.color.dark, NuriPalette.surface.dark) >= 4.5)
    }
}

@Suite struct SourceKindAliasTests {
    @Test func sourceKindIsFoodSource() {
        let kind: SourceKind = FoodSource.verified
        #expect(kind == .verified)
    }
}
