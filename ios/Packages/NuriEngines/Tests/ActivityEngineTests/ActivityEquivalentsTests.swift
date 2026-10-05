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
        // The catalog moderate column is used (never the vigorous column); the label follows the MET band.
        #expect(cycling.met == 6.8 && cycling.intensity == .vigorous)
        #expect(swim.met == 5.8 && swim.intensity == .moderate)
        for o in options {
            let a = try #require(catalog.activity(id: o.activityId))
            #expect(o.met == (a.met.moderate ?? a.met.light))
            #expect(o.intensity == Intensity.forMET(o.met))
        }
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

    @Test func exceedingAvailableTimeSuggestsSplitting() throws {
        // running: 40-60 min (within the 60-minute cap); cycling_outdoor: 50-70 min.
        guard case .options(let options) = ActivityEquivalents.recommend(
            input(kcal: 450, weight: 70, preferred: ["running", "cycling_outdoor"],
                  equipment: ["bicycle", "pool"], available: 45),
            catalog: catalog) else {
            Issue.record("expected options"); return
        }
        let running = try #require(options.first { $0.activityId == "running" })
        #expect(running.minutesLow == 40 && running.minutesHigh == 60)
        #expect(!running.suggestSplitting)
        let cycling = try #require(options.first { $0.activityId == "cycling_outdoor" })
        #expect(cycling.minutesLow == 50 && cycling.minutesHigh == 70)
        #expect(cycling.suggestSplitting)
    }

    @Test func availableTimeAloneTriggersSplitting() throws {
        // running 40-60 min is within the 60-minute cap, so only the 35-minute window can trigger a split.
        guard case .options(let options) = ActivityEquivalents.recommend(
            input(kcal: 450, weight: 70, preferred: ["running"], equipment: [], available: 35),
            catalog: catalog) else {
            Issue.record("expected options"); return
        }
        let running = try #require(options.first { $0.activityId == "running" })
        #expect(running.minutesLow == 40 && running.minutesHigh == 60)
        #expect(running.suggestSplitting)
    }

    @Test func withoutPreferencesModerateOptionsPrecedeVigorous() {
        // 450 kcal, 70 kg, bicycle + pool: running (8.3 MET, 40 min) and cycling (6.8 MET, 50 min) are vigorous
        // by the MET band, so they rank after every non-vigorous option even though they are shorter.
        guard case .options(let options) = ActivityEquivalents.recommend(input(), catalog: catalog) else {
            Issue.record("expected options"); return
        }
        let vigorous = options.filter { $0.intensity == .vigorous }
        let nonVigorous = options.filter { $0.intensity != .vigorous }
        #expect(!vigorous.isEmpty && !nonVigorous.isEmpty)
        let lastNonVigorous = options.lastIndex { $0.intensity != .vigorous } ?? -1
        let firstVigorous = options.firstIndex { $0.intensity == .vigorous } ?? options.count
        #expect(lastNonVigorous < firstVigorous)
        #expect(options.map(\.activityId) == ["swimming", "dancing", "strength_bodyweight", "walking", "running"])
        // Within each band, shorter minimum duration first.
        #expect(nonVigorous.map(\.minutesLow) == nonVigorous.map(\.minutesLow).sorted())
    }

    @Test func optionsThatFitAvailableTimeRankFirst() {
        // 55 min available: swimming (50), running (40) and cycling (50) fit; dancing (60) does not.
        guard case .options(let options) = ActivityEquivalents.recommend(input(available: 55), catalog: catalog) else {
            Issue.record("expected options"); return
        }
        #expect(options.map(\.activityId) == ["swimming", "running", "cycling_outdoor", "dancing", "walking"])
    }

    @Test func minimumEqualToAvailableTimeFitsWithoutSplitting() throws {
        // running: 40-60 min; exactly 40 min available still fits and needs no split.
        guard case .options(let options) = ActivityEquivalents.recommend(
            input(kcal: 450, weight: 70, preferred: [], equipment: [], available: 40),
            catalog: catalog) else {
            Issue.record("expected options"); return
        }
        let running = try #require(options.first { $0.activityId == "running" })
        #expect(running.minutesLow == 40 && running.minutesHigh == 60)
        #expect(!running.suggestSplitting)
        #expect(options.first?.activityId == "running") // the only option that fits 40 min
    }

    @Test func noEligibleActivitiesWithRestrictiveConstraintsSuppresses() {
        let result = ActivityEquivalents.recommend(
            input(equipment: [], mobility: [.seatedOnly]), catalog: catalog)
        #expect(result == .suppressed(.noEligibleActivities))
    }
}
