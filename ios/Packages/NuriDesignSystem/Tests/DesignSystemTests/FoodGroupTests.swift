import Testing
@testable import DesignSystem

@Suite struct FoodGroupTests {
    @Test func sixGroups() { #expect(FoodGroup.allCases.count == 6) }

    @Test(arguments: FoodGroup.allCases)
    func ringStandsOutFromGlobe(group: FoodGroup) {
        #expect(Contrast.ratio(group.ring.light, WorldPalette.globe.light) >= 3, "\(group) light")
        #expect(Contrast.ratio(group.ring.dark, WorldPalette.globe.dark) >= 3, "\(group) dark")
    }

    @Test func vegetablesAndProteinDifferInLightness() {
        // protan/deutan users confuse hue; lightness must separate these two neighbors
        let ratio = Contrast.ratio(FoodGroup.vegetables.fill, FoodGroup.protein.fill)
        #expect(ratio >= 1.5)
    }

    @Test func approvedFills() {
        #expect(FoodGroup.vegetables.fill == RGB(hex: 0x4F8A5B))
        #expect(FoodGroup.protein.fill == RGB(hex: 0x7E4127))
        #expect(FoodGroup.grains.fill == RGB(hex: 0xE2B54E))
    }

    @Test func haloIsThemedAndBlendsWithGlobeInDark() {
        #expect(WorldPalette.halo.dark == WorldPalette.globe.dark)
        #expect(WorldPalette.halo.light == RGB(hex: 0xFFFFFF))
    }
}
