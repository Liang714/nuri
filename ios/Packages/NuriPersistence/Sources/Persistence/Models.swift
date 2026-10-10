import Foundation
import SwiftData

/// One profile per device. Year of birth only (data minimization); sex is optional and only feeds the energy formula.
@Model
public final class ProfileRecord {
    public var birthYear: Int
    public var sexForEquation: String?
    public var heightCm: Double
    public var weightKg: Double
    public var activityLevel: String
    public var goal: String
    public var unitSystem: String
    public var bmiStandard: String
    public var lossDeficitKcal: Double
    public var activityShare: Double
    public var manualTargetKcal: Double?
    public var tracksWithoutGuide: Bool
    public var readinessYes: [String]
    public var preferredActivityIDs: [String]
    public var equipment: [String]
    public var mobility: [String]
    public var updatedAt: Date

    public init(birthYear: Int, sexForEquation: String?, heightCm: Double, weightKg: Double, activityLevel: String, goal: String,
                unitSystem: String, bmiStandard: String, lossDeficitKcal: Double = 250, activityShare: Double = 0.5,
                manualTargetKcal: Double? = nil, tracksWithoutGuide: Bool = false, readinessYes: [String] = [],
                preferredActivityIDs: [String] = [], equipment: [String] = [], mobility: [String] = [], updatedAt: Date = .now) {
        self.birthYear = birthYear
        self.sexForEquation = sexForEquation
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
        self.updatedAt = updatedAt
    }
}

/// A food the person created (label values). Database foods arrive with the food-data pipeline.
@Model
public final class FoodRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var foodGroup: String
    public var servingLabel: String
    public var gramsPerServing: Double
    public var energyKcalPer100g: Double
    public var proteinGPer100g: Double?
    public var carbsGPer100g: Double?
    public var fatGPer100g: Double?
    public var fiberGPer100g: Double?
    public var source: String
    public var isFavorite: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, foodGroup: String, servingLabel: String, gramsPerServing: Double,
                energyKcalPer100g: Double, proteinGPer100g: Double? = nil, carbsGPer100g: Double? = nil, fatGPer100g: Double? = nil,
                fiberGPer100g: Double? = nil, source: String, isFavorite: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.foodGroup = foodGroup
        self.servingLabel = servingLabel
        self.gramsPerServing = gramsPerServing
        self.energyKcalPer100g = energyKcalPer100g
        self.proteinGPer100g = proteinGPer100g
        self.carbsGPer100g = carbsGPer100g
        self.fatGPer100g = fatGPer100g
        self.fiberGPer100g = fiberGPer100g
        self.source = source
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }
}

/// A diary entry. Nutrition is a snapshot so history never changes when a food is edited (spec §6.2).
@Model
public final class MealEntryRecord {
    @Attribute(.unique) public var id: UUID
    public var foodID: UUID?
    public var foodName: String
    public var foodGroup: String
    public var mealType: String
    public var consumedAt: Date
    public var dayKey: String
    public var quantity: Double
    public var unitLabel: String
    public var grams: Double
    public var energyKcal: Double
    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?
    public var fiberG: Double?
    public var source: String
    public var createdAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), foodID: UUID?, foodName: String, foodGroup: String, mealType: String, consumedAt: Date, dayKey: String,
                quantity: Double, unitLabel: String, grams: Double, energyKcal: Double, proteinG: Double? = nil, carbsG: Double? = nil,
                fatG: Double? = nil, fiberG: Double? = nil, source: String, createdAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.foodID = foodID
        self.foodName = foodName
        self.foodGroup = foodGroup
        self.mealType = mealType
        self.consumedAt = consumedAt
        self.dayKey = dayKey
        self.quantity = quantity
        self.unitLabel = unitLabel
        self.grams = grams
        self.energyKcal = energyKcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.source = source
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

@Model
public final class ActivityLogRecord {
    @Attribute(.unique) public var id: UUID
    public var activityTypeID: String
    public var startAt: Date
    public var dayKey: String
    public var durationMinutes: Double
    public var intensity: String
    public var met: Double
    public var energyKcal: Double?
    public var energySource: String
    public var catalogVersion: String
    public var createdAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), activityTypeID: String, startAt: Date, dayKey: String, durationMinutes: Double, intensity: String,
                met: Double, energyKcal: Double?, energySource: String, catalogVersion: String, createdAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.activityTypeID = activityTypeID
        self.startAt = startAt
        self.dayKey = dayKey
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.met = met
        self.energyKcal = energyKcal
        self.energySource = energySource
        self.catalogVersion = catalogVersion
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

/// Append-only consent history (PIPA proof of consent): never edited, only added to, and deleted only with everything else.
@Model
public final class ConsentEventRecord {
    public var kind: String
    public var adultConfirmed: Bool
    public var healthDataConsented: Bool
    public var analyticsOptIn: Bool
    public var consentVersion: String
    public var localeIdentifier: String
    public var recordedAt: Date

    public init(kind: String, adultConfirmed: Bool, healthDataConsented: Bool, analyticsOptIn: Bool, consentVersion: String,
                localeIdentifier: String, recordedAt: Date) {
        self.kind = kind
        self.adultConfirmed = adultConfirmed
        self.healthDataConsented = healthDataConsented
        self.analyticsOptIn = analyticsOptIn
        self.consentVersion = consentVersion
        self.localeIdentifier = localeIdentifier
        self.recordedAt = recordedAt
    }
}
