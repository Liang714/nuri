import Foundation
import SwiftData
import Testing
@testable import Persistence

@MainActor
@Suite struct SchemaTests {
    @Test func inMemoryContainerStoresEveryModel() throws {
        let container = try NuriStore.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(ProfileRecord(birthYear: 1990, sexForEquation: nil, heightCm: 170, weightKg: 65,
                                     activityLevel: "lightlyActive", goal: "maintain", unitSystem: "metric", bmiStandard: "asianPacific"))
        context.insert(FoodRecord(name: "Rice, white, cooked", foodGroup: "grains", servingLabel: "1 bowl", gramsPerServing: 210,
                                  energyKcalPer100g: 130, source: "userCreated"))
        context.insert(MealEntryRecord(foodID: nil, foodName: "Rice, white, cooked", foodGroup: "grains", mealType: "lunch",
                                       consumedAt: Date(timeIntervalSince1970: 1_800_000_000), dayKey: "2027-01-15",
                                       quantity: 1, unitLabel: "1 bowl", grams: 210, energyKcal: 273, source: "userCreated"))
        context.insert(ActivityLogRecord(activityTypeID: "walking", startAt: Date(timeIntervalSince1970: 1_800_000_000), dayKey: "2027-01-15",
                                         durationMinutes: 30, intensity: "moderate", met: 3.5, energyKcal: nil,
                                         energySource: "manualMET", catalogVersion: "nuri-met-2026.1"))
        context.insert(ConsentEventRecord(kind: "granted", adultConfirmed: true, healthDataConsented: true, analyticsOptIn: false,
                                          consentVersion: "2026-10-10", localeIdentifier: "en_US", recordedAt: .now))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ProfileRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<FoodRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MealEntryRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ActivityLogRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ConsentEventRecord>()) == 1)
    }

    @Test func schemaIsVersioned() {
        #expect(NuriSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(NuriSchemaV1.models.count == 5)
    }
}
