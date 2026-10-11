import Foundation
import NuriDomain
import NutritionEngine
import Persistence
import SwiftData
import Testing
@testable import Nuri

@Suite struct ProfileDraftDefaultsTests {
    @Test func startingDraftHasTheDocumentedDefaults() {
        let draft = ProfileDraft.starting(regionCode: "KR", currentYear: 2026)
        #expect(draft.birthYear == 1996)
        #expect(draft.sex == nil)
        #expect(draft.heightCm == 170)
        #expect(draft.weightKg == 65)
        #expect(draft.activityLevel == .lightlyActive)
        #expect(draft.goal == .maintain)
        // Everything else stays at the draft's own defaults.
        #expect(draft.lossDeficitKcal == 250)
        #expect(draft.activityShare == 0.5)
        #expect(draft.manualTargetKcal == nil)
        #expect(!draft.tracksWithoutGuide)
        #expect(draft.readinessYes.isEmpty)
        #expect(draft.preferredActivityIDs.isEmpty)
        #expect(draft.equipment.isEmpty)
        #expect(draft.mobility.isEmpty)
    }

    @Test(arguments: [
        ("KR", UnitSystem.metric, BMIStandard.asianPacific),
        ("US", UnitSystem.imperial, BMIStandard.who),
        ("us", UnitSystem.imperial, BMIStandard.who),
        ("GB", UnitSystem.metric, BMIStandard.who),
        ("JP", UnitSystem.metric, BMIStandard.asianPacific),
    ])
    func unitsAndBMIStandardFollowTheRegion(region: String, units: UnitSystem, standard: BMIStandard) {
        let draft = ProfileDraft.starting(regionCode: region, currentYear: 2026)
        #expect(draft.unitSystem == units)
        #expect(draft.bmiStandard == standard)
    }

    @Test func noRegionMeansMetricAndWHO() {
        let draft = ProfileDraft.starting(regionCode: nil, currentYear: 2026)
        #expect(draft.unitSystem == .metric)
        #expect(draft.bmiStandard == .who)
    }

    @Test func startingDraftIsAnAdultTheEngineAccepts() throws {
        let draft = ProfileDraft.starting(regionCode: "KR", currentYear: 2026)
        #expect(draft.bodyProfile(inYear: 2026).ageYears == 30)
        _ = try draft.bodyProfile(inYear: 2026).validated()
    }

    // MARK: Year

    @Test func theYearIsGregorianWhateverTheDeviceCalendarIs() {
        // 2026-07-01 12:00 UTC: the same calendar year in every time zone.
        let date = Date(timeIntervalSince1970: 1_782_907_200)
        #expect(ProfileCalendar.currentYear(now: date) == 2026)
    }

    @Test func birthYearsRunFrom100To18YearsAgo() {
        let years = ProfileCalendar.birthYears(currentYear: 2026)
        #expect(years == 1926...2008)
        #expect(years.contains(ProfileDraft.starting(regionCode: nil, currentYear: 2026).birthYear))
    }

    // MARK: Editing bounds

    @Test func aDraftInsideTheBoundsIsUnchanged() {
        let draft = ProfileDraft.starting(regionCode: "US", currentYear: 2026)
        #expect(draft.clampedForEditing(currentYear: 2026) == draft)
    }

    @Test func yearAndHeightAreBroughtInsideWhatTheStepsCanShow() {
        var draft = ProfileDraft.starting(regionCode: "KR", currentYear: 2026)
        draft.birthYear = 1900
        draft.heightCm = 90
        var clamped = draft.clampedForEditing(currentYear: 2026)
        #expect(clamped.birthYear == 1926)
        #expect(clamped.heightCm == 100)

        draft.birthYear = 2020
        draft.heightCm = 300
        clamped = draft.clampedForEditing(currentYear: 2026)
        #expect(clamped.birthYear == 2008)
        #expect(clamped.heightCm == 250)

        draft.heightCm = .nan
        #expect(draft.clampedForEditing(currentYear: 2026).heightCm == 100)
    }

    @Test func clampingKeepsEveryOtherAnswer() {
        var draft = ProfileDraft.starting(regionCode: "KR", currentYear: 2026)
        draft.sex = .female
        draft.goal = .gradualLoss
        draft.readinessYes = [.pregnancy]
        draft.manualTargetKcal = 1800
        draft.birthYear = 1900
        let clamped = draft.clampedForEditing(currentYear: 2026)
        #expect(clamped.sex == .female)
        #expect(clamped.goal == .gradualLoss)
        #expect(clamped.readinessYes == [.pregnancy])
        #expect(clamped.manualTargetKcal == 1800)
    }

    // MARK: Opening draft

    @MainActor
    @Test func anEmptyStoreOpensWithTheStartingDraft() throws {
        // The container must outlive its context.
        let container = try NuriStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let opened = ProfileDraft.opening(context: context, regionCode: "US", currentYear: 2026)
        #expect(opened == ProfileDraft.starting(regionCode: "US", currentYear: 2026))
        withExtendedLifetime(container) {}
    }

    @MainActor
    @Test func aSavedProfileOpensInsteadOfTheDefaults() throws {
        // The container must outlive its context.
        let container = try NuriStore.makeContainer(inMemory: true)
        let context = container.mainContext
        var saved = ProfileDraft.starting(regionCode: "KR", currentYear: 2026)
        saved.birthYear = 1985
        saved.sex = .female
        saved.heightCm = 158
        saved.weightKg = 52.5
        saved.activityLevel = .veryActive
        saved.goal = .gradualLoss
        saved.unitSystem = .imperial
        saved.readinessYes = [.pregnancy, .boneOrJointProblem]
        saved.manualTargetKcal = 1650
        try ProfileRepository(context: context).save(saved, now: Date(timeIntervalSince1970: 1_800_000_000))

        // A different region and year must not matter once something is saved.
        let opened = ProfileDraft.opening(context: context, regionCode: "US", currentYear: 2026)
        #expect(opened == saved)
        #expect(opened != ProfileDraft.starting(regionCode: "US", currentYear: 2026))
        withExtendedLifetime(container) {}
    }

    @MainActor
    @Test func aSavedProfileOutsideTheStepBoundsIsBroughtInside() throws {
        // The container must outlive its context.
        let container = try NuriStore.makeContainer(inMemory: true)
        let context = container.mainContext
        var saved = ProfileDraft.starting(regionCode: "KR", currentYear: 2026)
        saved.birthYear = 1900
        try ProfileRepository(context: context).save(saved, now: .now)
        let opened = ProfileDraft.opening(context: context, regionCode: "KR", currentYear: 2026)
        #expect(opened.birthYear == 1926)
        withExtendedLifetime(container) {}
    }
}
