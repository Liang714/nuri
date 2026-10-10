import ActivityEngine
import Foundation
import NuriDomain
import NutritionEngine
import SwiftData
import Testing
@testable import Persistence

@MainActor
@Suite struct ProfileRepositoryTests {
    /// The container must outlive the context, so the fixture holds all three.
    @MainActor struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let repository: ProfileRepository

        init() throws {
            container = try NuriStore.makeContainer(inMemory: true)
            context = container.mainContext
            repository = ProfileRepository(context: context)
        }
    }

    static let fullDraft = ProfileDraft(
        birthYear: 1990, sex: .female, heightCm: 165.5, weightKg: 58.25,
        activityLevel: .moderatelyActive, goal: .gradualLoss, unitSystem: .imperial, bmiStandard: .asianPacific,
        lossDeficitKcal: 300, activityShare: 0.4, manualTargetKcal: 1650, tracksWithoutGuide: false,
        readinessYes: [.pregnancy, .boneOrJointProblem, .heartCondition],
        preferredActivityIDs: ["walking", "swimming", "yoga"],
        equipment: ["dumbbells", "bands", "mat"],
        mobility: [.seatedOnly, .lowImpactOnly]
    )

    @Test func draftDefaultsMatchTheBrief() {
        let draft = ProfileDraft(birthYear: 1990, sex: nil, heightCm: 170, weightKg: 65,
                                 activityLevel: .lightlyActive, goal: .maintain, unitSystem: .metric, bmiStandard: .who)
        #expect(draft.lossDeficitKcal == 250)
        #expect(draft.activityShare == 0.5)
        #expect(draft.manualTargetKcal == nil)
        #expect(draft.tracksWithoutGuide == false)
        #expect(draft.readinessYes.isEmpty)
        #expect(draft.preferredActivityIDs.isEmpty)
        #expect(draft.equipment.isEmpty)
        #expect(draft.mobility.isEmpty)
    }

    @Test func saveThenDraftRoundTripsEveryField() throws {
        let fx = try Fixture()
        try fx.repository.save(Self.fullDraft, now: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(try fx.repository.draft() == Self.fullDraft)
    }

    @Test func roundTripsOptionalsAsNilAndTrackingFlag() throws {
        let fx = try Fixture()
        let bare = ProfileDraft(birthYear: 2000, sex: nil, heightCm: 180, weightKg: 75,
                                activityLevel: .veryActive, goal: .trackOnly, unitSystem: .metric, bmiStandard: .who,
                                tracksWithoutGuide: true)
        try fx.repository.save(bare, now: .now)
        let loaded = try #require(try fx.repository.draft())
        #expect(loaded == bare)
        #expect(loaded.sex == nil)
        #expect(loaded.manualTargetKcal == nil)
        #expect(loaded.tracksWithoutGuide)
    }

    @Test func setsAreStoredSortedSoOutputIsDeterministic() throws {
        let fx = try Fixture()
        try fx.repository.save(Self.fullDraft, now: .now)
        let record = try #require(try fx.repository.current())
        #expect(record.readinessYes == ["boneOrJointProblem", "heartCondition", "pregnancy"])
        #expect(record.equipment == ["bands", "dumbbells", "mat"])
        #expect(record.mobility == ["lowImpactOnly", "seatedOnly"])
        #expect(record.preferredActivityIDs == ["walking", "swimming", "yoga"])
        #expect(record.sexForEquation == "female")
        #expect(record.activityLevel == "moderatelyActive")
        #expect(record.goal == "gradualLoss")
        #expect(record.unitSystem == "imperial")
        #expect(record.bmiStandard == "asianPacific")
    }

    @Test func secondSaveUpdatesTheSingleRecordAndBumpsUpdatedAt() throws {
        let fx = try Fixture()
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        let second = first.addingTimeInterval(3600)
        try fx.repository.save(Self.fullDraft, now: first)
        #expect(try fx.repository.current()?.updatedAt == first)

        var changed = Self.fullDraft
        changed.weightKg = 60
        changed.sex = nil
        changed.readinessYes = []
        try fx.repository.save(changed, now: second)

        #expect(try fx.context.fetchCount(FetchDescriptor<ProfileRecord>()) == 1)
        let record = try #require(try fx.repository.current())
        #expect(record.updatedAt == second)
        #expect(record.weightKg == 60)
        #expect(record.sexForEquation == nil)
        #expect(record.readinessYes.isEmpty)
        #expect(try fx.repository.draft() == changed)
    }

    @Test func existsIsFalseOnAnEmptyStoreAndTrueAfterASave() throws {
        let fx = try Fixture()
        #expect(try fx.repository.exists() == false)
        #expect(try fx.repository.current() == nil)
        #expect(try fx.repository.draft() == nil)
        try fx.repository.save(Self.fullDraft, now: .now)
        #expect(try fx.repository.exists())
    }

    @Test func unknownActivityLevelDecodesToSedentary() throws {
        let fx = try Fixture()
        fx.context.insert(ProfileRecord(birthYear: 1990, sexForEquation: nil, heightCm: 170, weightKg: 65,
                                        activityLevel: "flying", goal: "maintain", unitSystem: "metric", bmiStandard: "who"))
        try fx.context.save()
        #expect(try fx.repository.draft()?.activityLevel == .sedentary)
    }

    @Test func anUnknownReadinessAnswerStillNeedsClearance() throws {
        let fx = try Fixture()
        fx.context.insert(ProfileRecord(birthYear: 1990, sexForEquation: nil, heightCm: 170, weightKg: 65,
                                        activityLevel: "lightlyActive", goal: "maintain", unitSystem: "metric", bmiStandard: "who",
                                        readinessYes: ["someFutureQuestion"]))
        try fx.context.save()
        let draft = try #require(try fx.repository.draft())
        #expect(draft.readinessYes == [.otherMedicalReason])
        #expect(draft.readiness.needsClearance)
    }

    @Test func otherUnknownRawValuesFallBackToSafeDefaults() throws {
        let fx = try Fixture()
        fx.context.insert(ProfileRecord(birthYear: 1985, sexForEquation: "robot", heightCm: 170, weightKg: 65,
                                        activityLevel: "lightlyActive", goal: "teleport", unitSystem: "furlongs",
                                        bmiStandard: "martian",
                                        readinessYes: ["heartCondition", "telepathy", "pregnancy"],
                                        mobility: ["seatedOnly", "hovering"]))
        try fx.context.save()
        let draft = try #require(try fx.repository.draft())
        #expect(draft.sex == nil)
        #expect(draft.goal == .maintain)
        #expect(draft.unitSystem == .metric)
        #expect(draft.bmiStandard == .who)
        // An unknown readiness answer is kept as a "yes" (otherMedicalReason) so clearance is never silently dropped.
        #expect(draft.readinessYes == [.heartCondition, .pregnancy, .otherMedicalReason])
        #expect(draft.readiness.needsClearance)
        #expect(draft.mobility == [.seatedOnly])
        #expect(draft.activityLevel == .lightlyActive)
    }
}
