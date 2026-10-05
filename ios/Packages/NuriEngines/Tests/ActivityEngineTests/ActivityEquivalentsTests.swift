import Testing
@testable import ActivityEngine

@Suite struct ActivityEquivalentsTests {
    let catalog = try! METCatalog.bundled()

    func input(enabled: Bool = true, sensitive: Bool = false, kcal: Double = 450, weight: Double? = 70,
               preferred: [String] = [], equipment: Set<String> = ["bicycle", "pool"],
               available: Int? = nil, mobility: Set<MobilityPreference> = []) -> EquivalentsInput {
        EquivalentsInput(targetKcal: kcal, weightKg: weight, preferredActivityIds: preferred,
                         availableMinutes: available, equipment: equipment, mobility: mobility,
                         sensitiveMode: sensitive, enabled: enabled)
    }

    @Test func disabledByDefaultSuppresses() {
        #expect(ActivityEquivalents.recommend(input(enabled: false), catalog: catalog) == .suppressed(.disabled))
    }

    @Test func sensitiveModeSuppressesEvenWhenEnabled() {
        #expect(ActivityEquivalents.recommend(input(sensitive: true), catalog: catalog) == .suppressed(.sensitiveMode))
    }

    @Test func missingWeightOrInvalidTargetSuppresses() {
        #expect(ActivityEquivalents.recommend(input(weight: nil), catalog: catalog) == .suppressed(.missingWeight))
        #expect(ActivityEquivalents.recommend(input(kcal: 0), catalog: catalog) == .suppressed(.invalidTarget))
    }

    @Test func practicalRounding() {
        #expect(ActivityEquivalents.practicalMinutes(12.4) == (10, false))
        #expect(ActivityEquivalents.practicalMinutes(12.5) == (15, false))
        #expect(ActivityEquivalents.practicalMinutes(2) == (5, false))
        #expect(ActivityEquivalents.practicalMinutes(45.4) == (50, false))
        #expect(ActivityEquivalents.practicalMinutes(88) == (90, false))
        #expect(ActivityEquivalents.practicalMinutes(95) == (90, true))
    }

    @Test func rangesMatchSpecExample() throws {
        guard case .options(let options) = ActivityEquivalents.recommend(
            input(preferred: ["cycling_outdoor", "swimming", "walking"]), catalog: catalog) else {
            Issue.record("expected options"); return
        }
        let cycling = try #require(options.first { $0.activityId == "cycling_outdoor" })
        #expect(cycling.minutesLow == 50 && cycling.minutesHigh == 70 && !cycling.highIsOpenEnded)
        #expect(cycling.suggestSplitting) // 70 > 60-minute session cap
        let swim = try #require(options.first { $0.activityId == "swimming" })
        #expect(swim.minutesLow == 50 && swim.minutesHigh == 80)
        let walk = try #require(options.first { $0.activityId == "walking" })
        #expect(walk.highIsOpenEnded && walk.suggestSplitting)
        #expect(options.allSatisfy { $0.intensity != .vigorous })
    }

    @Test func preferredFirstCappedAtFiveAndIncludesWalking() {
        guard case .options(let options) = ActivityEquivalents.recommend(
            input(preferred: ["swimming"], equipment: ["bicycle", "pool", "stationary_bike", "elliptical"]),
            catalog: catalog) else {
            Issue.record("expected options"); return
        }
        #expect(options.count <= 5)
        #expect(options.first?.activityId == "swimming")
        #expect(options.contains { $0.activityId == "walking" })
    }

    @Test func smallTargetWithinSessionCapNeedsNoSplit() {
        guard case .options(let options) = ActivityEquivalents.recommend(input(kcal: 100), catalog: catalog) else {
            Issue.record("expected options"); return
        }
        #expect(options.allSatisfy { !$0.suggestSplitting })
    }

    @Test func timeFitRankingPlacesShortDurationsFirst() {
        guard case .options(let options) = ActivityEquivalents.recommend(
            input(kcal: 450, weight: 70, preferred: [], equipment: ["bicycle", "pool"], available: 60),
            catalog: catalog) else {
            Issue.record("expected options"); return
        }
        let fitsTimeIdx = options.firstIndex { o in o.minutesLow <= 60 && o.activityId != "walking" } ?? Int.max
        let exceedsTimeIdx = options.firstIndex { o in o.minutesLow > 60 && o.activityId != "walking" } ?? Int.max
        #expect(fitsTimeIdx < exceedsTimeIdx)
    }

    @Test func noEligibleActivitiesWithRestrictiveConstraintsSuppresses() {
        let result = ActivityEquivalents.recommend(
            input(equipment: [], mobility: [.seatedOnly]), catalog: catalog)
        #expect(result == .suppressed(.noEligibleActivities))
    }
}
