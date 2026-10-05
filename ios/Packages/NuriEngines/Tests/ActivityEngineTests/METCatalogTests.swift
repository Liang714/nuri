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

    @Test func plannerHardCodedActivitiesExistAndStrengthIsNeverVigorous() throws {
        let c = try METCatalog.bundled()
        for id in ["walking", "strength_bodyweight", "tai_chi", "cycling_stationary"] {
            #expect(c.activity(id: id) != nil, "\(id)")
        }
        // Columns the planner reads directly: clearance (light walking / stationary cycling), balance, strength.
        #expect(c.activity(id: "walking")?.met.light != nil)
        #expect(c.activity(id: "cycling_stationary")?.met.light != nil)
        #expect(c.activity(id: "tai_chi")?.met.light != nil)
        #expect(c.activity(id: "strength_bodyweight")?.met.moderate != nil)
        let strength = c.activities.filter { $0.category == .strength }
        #expect(!strength.isEmpty)
        for a in strength {
            let met = try #require(a.met.moderate, "\(a.id)")
            #expect(met < 6, "\(a.id)")
        }
    }

    @Test func intensityFollowsMETBand() {
        #expect(Intensity.forMET(2.99) == .light)
        #expect(Intensity.forMET(3.0) == .moderate)
        #expect(Intensity.forMET(5.99) == .moderate)
        #expect(Intensity.forMET(6.0) == .vigorous)
    }
}
