import Foundation
import SwiftData

public struct ExportFile: Equatable, Sendable {
    public let name: String
    public let data: Data

    public init(name: String, data: Data) {
        self.name = name
        self.data = data
    }
}

/// Builds the export promised in the privacy notice: everything stored, as CSV (for spreadsheets) and JSON (for backup).
///
/// Formats are locale-independent: dates are ISO 8601 in UTC, numbers use "." and no grouping, missing optionals are empty
/// CSV cells or JSON `null`. Soft-deleted rows are included with their `deleted_at`, since the export is the complete record.
@MainActor
public enum DataExport {
    public static let schemaVersion = 1

    /// The six files, in a fixed order.
    public static func files(from context: ModelContext, exportedAt: Date) throws -> [ExportFile] {
        // Every profile record is exported (normally one); the app itself reads only the most recently updated.
        let profiles = try context.fetch(FetchDescriptor<ProfileRecord>())
            .sorted { ($0.updatedAt, $0.birthYear) < ($1.updatedAt, $1.birthYear) }
            .map(ProfileDTO.init)
        let foods = try context.fetch(FetchDescriptor<FoodRecord>())
            .sorted { ($0.createdAt, $0.name, $0.id.uuidString) < ($1.createdAt, $1.name, $1.id.uuidString) }
        let meals = try context.fetch(FetchDescriptor<MealEntryRecord>())
            .sorted { ($0.consumedAt, $0.createdAt, $0.id.uuidString) < ($1.consumedAt, $1.createdAt, $1.id.uuidString) }
        let activities = try context.fetch(FetchDescriptor<ActivityLogRecord>())
            .sorted { ($0.startAt, $0.createdAt, $0.id.uuidString) < ($1.startAt, $1.createdAt, $1.id.uuidString) }
        let consent = try context.fetch(FetchDescriptor<ConsentEventRecord>())
            .sorted { ($0.recordedAt, $0.sequence) < ($1.recordedAt, $1.sequence) }
            .map(ConsentEventDTO.init)

        let backup = FullBackupDTO(schemaVersion: schemaVersion, exportedAt: exportedAt, profiles: profiles,
                                   foods: foods.map(FoodDTO.init), mealEntries: meals.map(MealEntryDTO.init),
                                   activities: activities.map(ActivityDTO.init), consentEvents: consent)
        let encoder = jsonEncoder()
        return [
            ExportFile(name: "profile.json", data: try encoder.encode(profiles)),
            ExportFile(name: "foods.csv", data: csvData(foodsCSV(foods))),
            ExportFile(name: "meal_entries.csv", data: csvData(mealEntriesCSV(meals))),
            ExportFile(name: "activities.csv", data: csvData(activitiesCSV(activities))),
            ExportFile(name: "consent_events.json", data: try encoder.encode(consent)),
            ExportFile(name: "full_backup.json", data: try encoder.encode(backup)),
        ]
    }

    /// Where exports are written for sharing. A fixed folder in the temporary directory, so "Delete everything" can find and remove it.
    public static var exportDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NuriExport", isDirectory: true)
    }

    /// Replaces `exportDirectory` with a fresh folder holding `files` (nothing from an earlier export survives) and returns their URLs.
    public static func writeToExportDirectory(_ files: [ExportFile]) throws -> [URL] {
        try removeExportDirectory()
        return try write(files, to: exportDirectory)
    }

    /// Removes `exportDirectory` and everything in it, if it exists.
    public static func removeExportDirectory() throws {
        guard FileManager.default.fileExists(atPath: exportDirectory.path) else { return }
        try FileManager.default.removeItem(at: exportDirectory)
    }

    /// Writes every file into `directory` (created if needed, existing files replaced) and returns their URLs in order.
    public static func write(_ files: [ExportFile], to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        let options: Data.WritingOptions = [.atomic, .completeFileProtection]
        #else
        let options: Data.WritingOptions = .atomic
        #endif
        return try files.map { file in
            let url = directory.appendingPathComponent(file.name, isDirectory: false)
            try file.data.write(to: url, options: options)
            return url
        }
    }

    /// RFC 4180: fields containing a comma, quote, CR or LF are quoted and embedded quotes doubled. Every record,
    /// including the last, ends with CRLF.
    public static func csv(_ rows: [[String]]) -> String {
        rows.map { $0.map(escape).joined(separator: ",") + "\r\n" }.joined()
    }

    // MARK: CSV

    /// CSV files start with a UTF-8 byte order mark so Excel opens Korean text as UTF-8 instead of the system code page.
    private static func csvData(_ text: String) -> Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    private static func foodsCSV(_ foods: [FoodRecord]) -> String {
        csv([[
            "id", "name", "food_group", "serving_label", "grams_per_serving", "energy_kcal_per_100g", "protein_g_per_100g",
            "carbs_g_per_100g", "fat_g_per_100g", "fiber_g_per_100g", "source", "is_favorite", "created_at",
        ]] + foods.map { food in
            [
                food.id.uuidString, food.name, food.foodGroup, food.servingLabel, number(food.gramsPerServing),
                number(food.energyKcalPer100g), number(food.proteinGPer100g), number(food.carbsGPer100g),
                number(food.fatGPer100g), number(food.fiberGPer100g), food.source, String(food.isFavorite), iso(food.createdAt),
            ]
        })
    }

    private static func mealEntriesCSV(_ meals: [MealEntryRecord]) -> String {
        csv([[
            "id", "consumed_at", "day_key", "meal_type", "food_name", "food_group", "quantity", "unit_label", "grams",
            "energy_kcal", "protein_g", "carbs_g", "fat_g", "fiber_g", "source", "deleted_at",
        ]] + meals.map { meal in
            [
                meal.id.uuidString, iso(meal.consumedAt), meal.dayKey, meal.mealType, meal.foodName, meal.foodGroup,
                number(meal.quantity), meal.unitLabel, number(meal.grams), number(meal.energyKcal), number(meal.proteinG),
                number(meal.carbsG), number(meal.fatG), number(meal.fiberG), meal.source, iso(meal.deletedAt),
            ]
        })
    }

    private static func activitiesCSV(_ activities: [ActivityLogRecord]) -> String {
        csv([[
            "id", "start_at", "day_key", "activity_type_id", "duration_minutes", "intensity", "met", "energy_kcal",
            "energy_source", "catalog_version", "deleted_at",
        ]] + activities.map { activity in
            [
                activity.id.uuidString, iso(activity.startAt), activity.dayKey, activity.activityTypeID,
                number(activity.durationMinutes), activity.intensity, number(activity.met), number(activity.energyKcal),
                activity.energySource, activity.catalogVersion, iso(activity.deletedAt),
            ]
        })
    }

    private static func escape(_ field: String) -> String {
        // Scalars, not Characters: "\r\n" is a single Character that equals neither "\r" nor "\n".
        let needsQuotes = field.unicodeScalars.contains { $0 == "," || $0 == "\"" || $0 == "\r" || $0 == "\n" }
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Locale-independent decimal: "." separator, no grouping, whole numbers without a trailing ".0".
    private static func number(_ value: Double) -> String {
        guard value.isFinite else { return nonFiniteText(value) }
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        return String(value)
    }

    private static func number(_ value: Double?) -> String {
        value.map { number($0) } ?? ""
    }

    private static func iso(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    private static func iso(_ date: Date?) -> String {
        date.map { iso($0) } ?? ""
    }

    private static func nonFiniteText(_ value: Double) -> String {
        value.isNaN ? "NaN" : (value < 0 ? "-Infinity" : "Infinity")
    }

    // MARK: JSON

    private static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        // A single corrupt value must never stop a person exporting their data.
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return encoder
    }
}

// MARK: - DTOs
// Optionals are encoded explicitly (`null`), never omitted, so the JSON shape is the same for every row.

struct ProfileDTO: Codable, Equatable {
    var birthYear: Int
    var sex: String?
    var heightCm: Double
    var weightKg: Double
    var activityLevel: String
    var goal: String
    var unitSystem: String
    var bmiStandard: String
    var lossDeficitKcal: Double
    var activityShare: Double
    var manualTargetKcal: Double?
    var tracksWithoutGuide: Bool
    var readinessYes: [String]
    var preferredActivityIDs: [String]
    var equipment: [String]
    var mobility: [String]
    var updatedAt: Date

    init(_ record: ProfileRecord) {
        birthYear = record.birthYear
        sex = record.sexForEquation
        heightCm = record.heightCm
        weightKg = record.weightKg
        activityLevel = record.activityLevel
        goal = record.goal
        unitSystem = record.unitSystem
        bmiStandard = record.bmiStandard
        lossDeficitKcal = record.lossDeficitKcal
        activityShare = record.activityShare
        manualTargetKcal = record.manualTargetKcal
        tracksWithoutGuide = record.tracksWithoutGuide
        readinessYes = record.readinessYes
        preferredActivityIDs = record.preferredActivityIDs
        equipment = record.equipment
        mobility = record.mobility
        updatedAt = record.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case birthYear, sex, heightCm, weightKg, activityLevel, goal, unitSystem, bmiStandard, lossDeficitKcal, activityShare,
             manualTargetKcal, tracksWithoutGuide, readinessYes, preferredActivityIDs, equipment, mobility, updatedAt
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(birthYear, forKey: .birthYear)
        try c.encode(sex, forKey: .sex)
        try c.encode(heightCm, forKey: .heightCm)
        try c.encode(weightKg, forKey: .weightKg)
        try c.encode(activityLevel, forKey: .activityLevel)
        try c.encode(goal, forKey: .goal)
        try c.encode(unitSystem, forKey: .unitSystem)
        try c.encode(bmiStandard, forKey: .bmiStandard)
        try c.encode(lossDeficitKcal, forKey: .lossDeficitKcal)
        try c.encode(activityShare, forKey: .activityShare)
        try c.encode(manualTargetKcal, forKey: .manualTargetKcal)
        try c.encode(tracksWithoutGuide, forKey: .tracksWithoutGuide)
        try c.encode(readinessYes, forKey: .readinessYes)
        try c.encode(preferredActivityIDs, forKey: .preferredActivityIDs)
        try c.encode(equipment, forKey: .equipment)
        try c.encode(mobility, forKey: .mobility)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

struct FoodDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var foodGroup: String
    var servingLabel: String
    var gramsPerServing: Double
    var energyKcalPer100g: Double
    var proteinGPer100g: Double?
    var carbsGPer100g: Double?
    var fatGPer100g: Double?
    var fiberGPer100g: Double?
    var source: String
    var isFavorite: Bool
    var createdAt: Date

    init(_ record: FoodRecord) {
        id = record.id
        name = record.name
        foodGroup = record.foodGroup
        servingLabel = record.servingLabel
        gramsPerServing = record.gramsPerServing
        energyKcalPer100g = record.energyKcalPer100g
        proteinGPer100g = record.proteinGPer100g
        carbsGPer100g = record.carbsGPer100g
        fatGPer100g = record.fatGPer100g
        fiberGPer100g = record.fiberGPer100g
        source = record.source
        isFavorite = record.isFavorite
        createdAt = record.createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, foodGroup, servingLabel, gramsPerServing, energyKcalPer100g, proteinGPer100g, carbsGPer100g,
             fatGPer100g, fiberGPer100g, source, isFavorite, createdAt
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(foodGroup, forKey: .foodGroup)
        try c.encode(servingLabel, forKey: .servingLabel)
        try c.encode(gramsPerServing, forKey: .gramsPerServing)
        try c.encode(energyKcalPer100g, forKey: .energyKcalPer100g)
        try c.encode(proteinGPer100g, forKey: .proteinGPer100g)
        try c.encode(carbsGPer100g, forKey: .carbsGPer100g)
        try c.encode(fatGPer100g, forKey: .fatGPer100g)
        try c.encode(fiberGPer100g, forKey: .fiberGPer100g)
        try c.encode(source, forKey: .source)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

struct MealEntryDTO: Codable, Equatable {
    var id: UUID
    var foodID: UUID?
    var foodName: String
    var foodGroup: String
    var mealType: String
    var consumedAt: Date
    var dayKey: String
    var quantity: Double
    var unitLabel: String
    var grams: Double
    var energyKcal: Double
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var source: String
    var createdAt: Date
    var deletedAt: Date?

    init(_ record: MealEntryRecord) {
        id = record.id
        foodID = record.foodID
        foodName = record.foodName
        foodGroup = record.foodGroup
        mealType = record.mealType
        consumedAt = record.consumedAt
        dayKey = record.dayKey
        quantity = record.quantity
        unitLabel = record.unitLabel
        grams = record.grams
        energyKcal = record.energyKcal
        proteinG = record.proteinG
        carbsG = record.carbsG
        fatG = record.fatG
        fiberG = record.fiberG
        source = record.source
        createdAt = record.createdAt
        deletedAt = record.deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, foodID, foodName, foodGroup, mealType, consumedAt, dayKey, quantity, unitLabel, grams, energyKcal,
             proteinG, carbsG, fatG, fiberG, source, createdAt, deletedAt
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(foodID, forKey: .foodID)
        try c.encode(foodName, forKey: .foodName)
        try c.encode(foodGroup, forKey: .foodGroup)
        try c.encode(mealType, forKey: .mealType)
        try c.encode(consumedAt, forKey: .consumedAt)
        try c.encode(dayKey, forKey: .dayKey)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(unitLabel, forKey: .unitLabel)
        try c.encode(grams, forKey: .grams)
        try c.encode(energyKcal, forKey: .energyKcal)
        try c.encode(proteinG, forKey: .proteinG)
        try c.encode(carbsG, forKey: .carbsG)
        try c.encode(fatG, forKey: .fatG)
        try c.encode(fiberG, forKey: .fiberG)
        try c.encode(source, forKey: .source)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

struct ActivityDTO: Codable, Equatable {
    var id: UUID
    var activityTypeID: String
    var startAt: Date
    var dayKey: String
    var durationMinutes: Double
    var intensity: String
    var met: Double
    var energyKcal: Double?
    var energySource: String
    var catalogVersion: String
    var createdAt: Date
    var deletedAt: Date?

    init(_ record: ActivityLogRecord) {
        id = record.id
        activityTypeID = record.activityTypeID
        startAt = record.startAt
        dayKey = record.dayKey
        durationMinutes = record.durationMinutes
        intensity = record.intensity
        met = record.met
        energyKcal = record.energyKcal
        energySource = record.energySource
        catalogVersion = record.catalogVersion
        createdAt = record.createdAt
        deletedAt = record.deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, activityTypeID, startAt, dayKey, durationMinutes, intensity, met, energyKcal, energySource,
             catalogVersion, createdAt, deletedAt
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(activityTypeID, forKey: .activityTypeID)
        try c.encode(startAt, forKey: .startAt)
        try c.encode(dayKey, forKey: .dayKey)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(intensity, forKey: .intensity)
        try c.encode(met, forKey: .met)
        try c.encode(energyKcal, forKey: .energyKcal)
        try c.encode(energySource, forKey: .energySource)
        try c.encode(catalogVersion, forKey: .catalogVersion)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

struct ConsentEventDTO: Codable, Equatable {
    var kind: String
    var adultConfirmed: Bool
    var healthDataConsented: Bool
    var analyticsOptIn: Bool
    var consentVersion: String
    var localeIdentifier: String
    var recordedAt: Date
    var sequence: Int

    init(_ record: ConsentEventRecord) {
        kind = record.kind
        adultConfirmed = record.adultConfirmed
        healthDataConsented = record.healthDataConsented
        analyticsOptIn = record.analyticsOptIn
        consentVersion = record.consentVersion
        localeIdentifier = record.localeIdentifier
        recordedAt = record.recordedAt
        sequence = record.sequence
    }
}

struct FullBackupDTO: Codable, Equatable {
    var schemaVersion: Int
    var exportedAt: Date
    var profiles: [ProfileDTO]
    var foods: [FoodDTO]
    var mealEntries: [MealEntryDTO]
    var activities: [ActivityDTO]
    var consentEvents: [ConsentEventDTO]

    init(schemaVersion: Int, exportedAt: Date, profiles: [ProfileDTO], foods: [FoodDTO], mealEntries: [MealEntryDTO],
         activities: [ActivityDTO], consentEvents: [ConsentEventDTO]) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.profiles = profiles
        self.foods = foods
        self.mealEntries = mealEntries
        self.activities = activities
        self.consentEvents = consentEvents
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, profiles, foods, mealEntries, activities, consentEvents
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(profiles, forKey: .profiles)
        try c.encode(foods, forKey: .foods)
        try c.encode(mealEntries, forKey: .mealEntries)
        try c.encode(activities, forKey: .activities)
        try c.encode(consentEvents, forKey: .consentEvents)
    }
}
