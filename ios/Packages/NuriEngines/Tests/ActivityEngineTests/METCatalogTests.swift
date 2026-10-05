import Testing
@testable import ActivityEngine

func approx(_ a: Double, _ b: Double, tol: Double = 0.01) -> Bool { abs(a - b) <= tol }

@Suite struct METCatalogTests {
    @Test func bundledCatalogLoadsWithVersionAndSource() throws {
        let c = try METCatalog.bundled()
        #expect(c.version == "nuri-met-2026.1")
        #expect(c.sourceReference.contains("Compendium"))
        #expect(c.activity(id: "walking")?.met.value(for: .moderate) == 3.5)
        #expect(c.activity(id: "elliptical")?.met.value(for: .light) == nil)
    }

    @Test func everyActivityHasAtLeastOneMETAndUniqueId() throws {
        let c = try METCatalog.bundled()
        #expect(Set(c.activities.map(\.id)).count == c.activities.count)
        for a in c.activities {
            #expect(a.met.light != nil || a.met.moderate != nil || a.met.vigorous != nil, "\(a.id)")
        }
    }

    @Test func eligibilityRespectsEquipmentAndMobility() throws {
        let c = try METCatalog.bundled()
        let noGear = c.eligible(category: .aerobic, equipment: [], mobility: [], requireLowImpact: false).map(\.id)
        #expect(noGear.contains("walking"))
        #expect(!noGear.contains("swimming"))

        let lowImpact = c.eligible(category: .aerobic, equipment: ["pool"], mobility: [.lowImpactOnly], requireLowImpact: false).map(\.id)
        #expect(lowImpact.contains("swimming"))
        #expect(!lowImpact.contains("running"))

        let seated = c.eligible(category: .aerobic, equipment: ["stationary_bike"], mobility: [.seatedOnly], requireLowImpact: false).map(\.id)
        #expect(seated == ["cycling_stationary"])

        let obese = c.eligible(category: .aerobic, equipment: [], mobility: [], requireLowImpact: true).map(\.id)
        #expect(!obese.contains("running"))
    }
}
