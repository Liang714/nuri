import ActivityEngine
import Foundation
import NuriDomain
import NutritionEngine
import SwiftData

/// The person's profile as the app edits it: domain enums and sets instead of the stored raw strings.
public struct ProfileDraft: Equatable, Sendable {
    public var birthYear: Int
    public var sex: SexForEquation?
    public var heightCm: Double
    public var weightKg: Double
    public var activityLevel: ActivityLevel
    public var goal: Goal
    public var unitSystem: UnitSystem
    public var bmiStandard: BMIStandard
    public var lossDeficitKcal: Double
    public var activityShare: Double
    public var manualTargetKcal: Double?
    public var tracksWithoutGuide: Bool
    public var readinessYes: Set<ReadinessQuestion>
    public var preferredActivityIDs: [String]
    public var equipment: Set<String>
    public var mobility: Set<MobilityPreference>

    public init(birthYear: Int, sex: SexForEquation?, heightCm: Double, weightKg: Double, activityLevel: ActivityLevel, goal: Goal,
                unitSystem: UnitSystem, bmiStandard: BMIStandard, lossDeficitKcal: Double = 250, activityShare: Double = 0.5,
                manualTargetKcal: Double? = nil, tracksWithoutGuide: Bool = false, readinessYes: Set<ReadinessQuestion> = [],
                preferredActivityIDs: [String] = [], equipment: Set<String> = [], mobility: Set<MobilityPreference> = []) {
        self.birthYear = birthYear
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
        self.unitSystem = unitSystem
        self.bmiStandard = bmiStandard
        self.lossDeficitKcal = lossDeficitKcal
        self.activityShare = activityShare
        self.manualTargetKcal = manualTargetKcal
        self.tracksWithoutGuide = tracksWithoutGuide
        self.readinessYes = readinessYes
        self.preferredActivityIDs = preferredActivityIDs
        self.equipment = equipment
        self.mobility = mobility
    }
}

/// Reads and writes the single per-device profile. Enums are stored as raw strings; sets are stored sorted so the
/// stored (and exported) form is deterministic.
@MainActor
public final class ProfileRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func current() throws -> ProfileRecord? {
        var descriptor = FetchDescriptor<ProfileRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func exists() throws -> Bool {
        try context.fetchCount(FetchDescriptor<ProfileRecord>()) > 0
    }

    public func draft() throws -> ProfileDraft? {
        try current().map(Self.draft(from:))
    }

    /// Upserts the single profile record.
    public func save(_ draft: ProfileDraft, now: Date) throws {
        let record: ProfileRecord
        if let existing = try current() {
            record = existing
        } else {
            record = ProfileRecord(birthYear: draft.birthYear, sexForEquation: nil, heightCm: draft.heightCm,
                                   weightKg: draft.weightKg, activityLevel: draft.activityLevel.rawValue,
                                   goal: draft.goal.rawValue, unitSystem: draft.unitSystem.rawValue,
                                   bmiStandard: draft.bmiStandard.rawValue)
            context.insert(record)
        }
        record.birthYear = draft.birthYear
        record.sexForEquation = draft.sex?.rawValue
        record.heightCm = draft.heightCm
        record.weightKg = draft.weightKg
        record.activityLevel = draft.activityLevel.rawValue
        record.goal = draft.goal.rawValue
        record.unitSystem = draft.unitSystem.rawValue
        record.bmiStandard = draft.bmiStandard.rawValue
        record.lossDeficitKcal = draft.lossDeficitKcal
        record.activityShare = draft.activityShare
        record.manualTargetKcal = draft.manualTargetKcal
        record.tracksWithoutGuide = draft.tracksWithoutGuide
        record.readinessYes = draft.readinessYes.map(\.rawValue).sorted()
        record.preferredActivityIDs = draft.preferredActivityIDs
        record.equipment = draft.equipment.sorted()
        record.mobility = draft.mobility.map(\.rawValue).sorted()
        record.updatedAt = now
        try context.save()
    }

    /// Unknown raw values (a newer or damaged store) fall back to safe defaults; unknown set entries are dropped.
    private static func draft(from record: ProfileRecord) -> ProfileDraft {
        ProfileDraft(
            birthYear: record.birthYear,
            sex: record.sexForEquation.flatMap(SexForEquation.init(rawValue:)),
            heightCm: record.heightCm,
            weightKg: record.weightKg,
            activityLevel: ActivityLevel(rawValue: record.activityLevel) ?? .sedentary,
            goal: Goal(rawValue: record.goal) ?? .maintain,
            unitSystem: UnitSystem(rawValue: record.unitSystem) ?? .metric,
            bmiStandard: BMIStandard(rawValue: record.bmiStandard) ?? .who,
            lossDeficitKcal: record.lossDeficitKcal,
            activityShare: record.activityShare,
            manualTargetKcal: record.manualTargetKcal,
            tracksWithoutGuide: record.tracksWithoutGuide,
            readinessYes: Set(record.readinessYes.compactMap(ReadinessQuestion.init(rawValue:))),
            preferredActivityIDs: record.preferredActivityIDs,
            equipment: Set(record.equipment),
            mobility: Set(record.mobility.compactMap(MobilityPreference.init(rawValue:)))
        )
    }
}
