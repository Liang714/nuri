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

    /// 2026-07-01 12:00 UTC: the same calendar year in every time zone.
    private static let midYear = Date(timeIntervalSince1970: 1_782_907_200)
    private static let utc = TimeZone(identifier: "UTC")!

    private static func calendar(_ identifier: Calendar.Identifier, in zone: TimeZone = utc) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = zone
        return calendar
    }

    @Test func theYearIsGregorianWhateverTheDeviceCalendarIs() {
        // The device calendar goes in as an argument, so a version that read it (or Calendar.current) would show a
        // Buddhist 2569 or a Japanese Reiwa 8 here. Each control line shows that the calendar really differs.
        let buddhist = Self.calendar(.buddhist)
        #expect(buddhist.component(.year, from: Self.midYear) == 2569)
        #expect(ProfileCalendar.currentYear(now: Self.midYear, deviceCalendar: buddhist) == 2026)

        let japanese = Self.calendar(.japanese)
        #expect(japanese.component(.year, from: Self.midYear) == 8)
        #expect(ProfileCalendar.currentYear(now: Self.midYear, deviceCalendar: japanese) == 2026)

        let persian = Self.calendar(.persian)
        #expect(persian.component(.year, from: Self.midYear) == 1405)
        #expect(ProfileCalendar.currentYear(now: Self.midYear, deviceCalendar: persian) == 2026)

        #expect(ProfileCalendar.currentYear(now: Self.midYear, deviceCalendar: Self.calendar(.gregorian)) == 2026)
    }

    @Test func theYearFollowsTheDeviceTimeZone() throws {
        // 2026-12-31 23:30 UTC is already New Year's Day 2027 in Seoul (UTC+9), and still 2026 in UTC and in New York.
        let lateOnNewYearsEve = Date(timeIntervalSince1970: 1_798_759_800)
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        #expect(ProfileCalendar.currentYear(now: lateOnNewYearsEve, deviceCalendar: Self.calendar(.buddhist, in: seoul)) == 2027)
        #expect(ProfileCalendar.currentYear(now: lateOnNewYearsEve, deviceCalendar: Self.calendar(.gregorian, in: newYork)) == 2026)
        #expect(ProfileCalendar.currentYear(now: lateOnNewYearsEve, deviceCalendar: Self.calendar(.gregorian)) == 2026)
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

    // MARK: Prefill once

    @MainActor
    @Test func theOpeningDraftIsReadOnceNoMatterHowOftenTheViewAsks() {
        let box = OpeningDraftBox()
        var reads = 0
        let first = box.draft {
            reads += 1
            return ProfileDraft.starting(regionCode: "KR", currentYear: 2026)
        }
        let second = box.draft {
            reads += 1
            return ProfileDraft.starting(regionCode: "US", currentYear: 2030)
        }
        #expect(reads == 1, "the store is read on the first ask only")
        #expect(second == first, "later asks return the first draft, not a fresh read")
    }
}
