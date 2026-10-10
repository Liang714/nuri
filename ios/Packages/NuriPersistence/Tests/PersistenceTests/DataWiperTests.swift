import Foundation
import SwiftData
import Testing
@testable import Persistence

@MainActor
@Suite struct DataWiperTests {
    private func counts(_ context: ModelContext) throws -> [Int] {
        [
            try context.fetchCount(FetchDescriptor<ProfileRecord>()),
            try context.fetchCount(FetchDescriptor<FoodRecord>()),
            try context.fetchCount(FetchDescriptor<MealEntryRecord>()),
            try context.fetchCount(FetchDescriptor<ActivityLogRecord>()),
            try context.fetchCount(FetchDescriptor<ConsentEventRecord>()),
        ]
    }

    private func populate(_ context: ModelContext) throws {
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(ProfileRecord(birthYear: 1990, sexForEquation: nil, heightCm: 170, weightKg: 65,
                                     activityLevel: "lightlyActive", goal: "maintain", unitSystem: "metric", bmiStandard: "who"))
        context.insert(FoodRecord(name: "Rice", foodGroup: "grains", servingLabel: "1 bowl", gramsPerServing: 210,
                                  energyKcalPer100g: 130, source: "userCreated"))
        context.insert(FoodRecord(name: "Kimchi", foodGroup: "vegetables", servingLabel: "1 side", gramsPerServing: 40,
                                  energyKcalPer100g: 15, source: "userCreated"))
        context.insert(MealEntryRecord(foodID: nil, foodName: "Rice", foodGroup: "grains", mealType: "lunch", consumedAt: when,
                                       dayKey: "2027-01-15", quantity: 1, unitLabel: "1 bowl", grams: 210, energyKcal: 273,
                                       source: "userCreated"))
        context.insert(MealEntryRecord(foodID: nil, foodName: "Deleted", foodGroup: "grains", mealType: "lunch", consumedAt: when,
                                       dayKey: "2027-01-15", quantity: 1, unitLabel: "1", grams: 10, energyKcal: 10,
                                       source: "userCreated", deletedAt: when))
        context.insert(ActivityLogRecord(activityTypeID: "walking", startAt: when, dayKey: "2027-01-15", durationMinutes: 30,
                                         intensity: "moderate", met: 3.5, energyKcal: nil, energySource: "manualMET",
                                         catalogVersion: "nuri-met-2026.1"))
        context.insert(ConsentEventRecord(kind: "granted", adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                          consentVersion: "2026-10-10", localeIdentifier: "en_US", recordedAt: when))
        context.insert(ConsentEventRecord(kind: "withdrawn", adultConfirmed: true, healthDataConsented: false, analyticsOptIn: false,
                                          consentVersion: "2026-10-10", localeIdentifier: "en_US", recordedAt: when.addingTimeInterval(1)))
        try context.save()
    }

    @Test func deleteEverythingLeavesAllFiveModelsEmpty() throws {
        let container = try NuriStore.makeContainer(inMemory: true)
        let context = container.mainContext
        try populate(context)
        #expect(try counts(context) == [1, 2, 2, 1, 2])

        try DataWiper.deleteEverything(in: context)

        #expect(try counts(context) == [0, 0, 0, 0, 0])
    }

    @Test func deleteEverythingIsDurableAcrossAFreshContext() throws {
        let container = try NuriStore.makeContainer(inMemory: true)
        try populate(container.mainContext)
        try DataWiper.deleteEverything(in: container.mainContext)
        #expect(try counts(ModelContext(container)) == [0, 0, 0, 0, 0])
    }

    @Test func deleteEverythingOnAnEmptyStoreIsHarmlessAndTheStoreIsReusable() throws {
        let container = try NuriStore.makeContainer(inMemory: true)
        let context = container.mainContext
        try DataWiper.deleteEverything(in: context)
        #expect(try counts(context) == [0, 0, 0, 0, 0])
        try populate(context)
        #expect(try counts(context) == [1, 2, 2, 1, 2])
    }

    @Test func deleteEverythingAlsoRemovesUnsavedInserts() throws {
        let container = try NuriStore.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(ConsentEventRecord(kind: "granted", adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                          consentVersion: "2026-10-10", localeIdentifier: "en_US", recordedAt: .now))
        try DataWiper.deleteEverything(in: context)
        #expect(try counts(context) == [0, 0, 0, 0, 0])
    }
}
