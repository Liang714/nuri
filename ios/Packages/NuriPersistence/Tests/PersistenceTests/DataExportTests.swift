import Foundation
import SwiftData
import Testing
@testable import Persistence

/// A minimal RFC 4180 reader so the tests check what a spreadsheet would read back, not the writer's own output.
private func parseCSV(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var field = String.UnicodeScalarView()
    var inQuotes = false
    var iterator = text.unicodeScalars.makeIterator()
    var pending: Unicode.Scalar? = iterator.next()
    func endField() {
        row.append(String(field))
        field = String.UnicodeScalarView()
    }
    while let scalar = pending {
        pending = iterator.next()
        if inQuotes {
            if scalar == "\"" {
                if pending == "\"" {
                    field.append("\"")
                    pending = iterator.next()
                } else {
                    inQuotes = false
                }
            } else {
                field.append(scalar)
            }
        } else if scalar == "\"" {
            inQuotes = true
        } else if scalar == "," {
            endField()
        } else if scalar == "\r", pending == "\n" {
            pending = iterator.next()
            endField()
            rows.append(row)
            row = []
        } else {
            field.append(scalar)
        }
    }
    if !field.isEmpty || !row.isEmpty {
        endField()
        rows.append(row)
    }
    return rows
}

@MainActor
@Suite struct DataExportTests {
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15T08:00:00Z
    static let exportedAt = Date(timeIntervalSince1970: 1_800_100_000) // 2027-01-16T11:46:40Z

    static let fileNames = ["profile.json", "foods.csv", "meal_entries.csv", "activities.csv", "consent_events.json", "full_backup.json"]
    static let foodsHeader = "id,name,food_group,serving_label,grams_per_serving,energy_kcal_per_100g,protein_g_per_100g,"
        + "carbs_g_per_100g,fat_g_per_100g,fiber_g_per_100g,source,is_favorite,created_at"
    static let mealsHeader = "id,consumed_at,day_key,meal_type,food_name,food_group,quantity,unit_label,grams,energy_kcal,"
        + "protein_g,carbs_g,fat_g,fiber_g,source,deleted_at"
    static let activitiesHeader = "id,start_at,day_key,activity_type_id,duration_minutes,intensity,met,energy_kcal,energy_source,"
        + "catalog_version,deleted_at"

    func container() throws -> ModelContainer { try NuriStore.makeContainer(inMemory: true) }

    func file(_ files: [ExportFile], _ name: String) throws -> ExportFile {
        try #require(files.first { $0.name == name })
    }

    func text(_ file: ExportFile) throws -> String {
        try #require(String(data: file.data, encoding: .utf8))
    }

    // MARK: CSV writer

    @Test func csvQuotesOnlyWhatRFC4180Requires() {
        #expect(DataExport.csv([["plain"]]) == "plain\r\n")
        #expect(DataExport.csv([["a,b"]]) == "\"a,b\"\r\n")
        #expect(DataExport.csv([["say \"hi\""]]) == "\"say \"\"hi\"\"\"\r\n")
        #expect(DataExport.csv([["line1\nline2"]]) == "\"line1\nline2\"\r\n")
        #expect(DataExport.csv([["a\rb"]]) == "\"a\rb\"\r\n")
        // "\r\n" is a single Character in Swift; it must still trigger quoting.
        #expect(DataExport.csv([["a\r\nb"]]) == "\"a\r\nb\"\r\n")
        #expect(DataExport.csv([["", "x"]]) == ",x\r\n")
        #expect(DataExport.csv([[" padded "]]) == " padded \r\n")
        #expect(DataExport.csv([["김치찌개"]]) == "김치찌개\r\n")
    }

    @Test func csvJoinsFieldsWithCommasAndRowsWithCRLF() {
        #expect(DataExport.csv([["a", "b"], ["c,d", ""]]) == "a,b\r\n\"c,d\",\r\n")
        #expect(DataExport.csv([]) == "")
    }

    @Test func csvOutputParsesBackToTheSameFields() {
        let rows = [["id", "note"], ["1", "he said \"no\", twice"], ["2", "two\r\nlines"], ["3", ""], ["4", "김치, 밥"]]
        #expect(parseCSV(DataExport.csv(rows)) == rows)
    }

    // MARK: Empty store

    @Test func emptyStoreGivesSixFilesWithHeaderOnlyCSVsAndANullProfile() throws {
        let c = try container()
        let files = try DataExport.files(from: c.mainContext, exportedAt: Self.exportedAt)

        #expect(files.map(\.name) == Self.fileNames)
        #expect(try text(file(files, "foods.csv")) == Self.foodsHeader + "\r\n")
        #expect(try text(file(files, "meal_entries.csv")) == Self.mealsHeader + "\r\n")
        #expect(try text(file(files, "activities.csv")) == Self.activitiesHeader + "\r\n")
        #expect(try text(file(files, "profile.json")) == "null")
        // Pretty-printed JSON writes an empty array as "[\n\n]"; what matters is that it is an empty JSON array.
        let consent = try #require(try JSONSerialization.jsonObject(with: file(files, "consent_events.json").data) as? [Any])
        #expect(consent.isEmpty)

        let backup = try JSONDecoder.iso.decode(FullBackupDTO.self, from: file(files, "full_backup.json").data)
        #expect(backup.schemaVersion == 1)
        #expect(backup.schemaVersion == DataExport.schemaVersion)
        #expect(backup.exportedAt == Self.exportedAt)
        #expect(backup.profile == nil)
        #expect(backup.foods.isEmpty && backup.mealEntries.isEmpty && backup.activities.isEmpty && backup.consentEvents.isEmpty)

        let object = try #require(try JSONSerialization.jsonObject(with: file(files, "full_backup.json").data) as? [String: Any])
        #expect(object["profile"] is NSNull)
        #expect(Set(object.keys) == ["schemaVersion", "exportedAt", "profile", "foods", "mealEntries", "activities", "consentEvents"])
    }

    // MARK: Populated store

    static let kimchiID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let mealID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let deletedMealID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let activityID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let deletedActivityID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

    func populate(_ context: ModelContext) throws {
        context.insert(ProfileRecord(birthYear: 1990, sexForEquation: "female", heightCm: 165.5, weightKg: 58.25,
                                     activityLevel: "moderatelyActive", goal: "gradualLoss", unitSystem: "metric",
                                     bmiStandard: "asianPacific", lossDeficitKcal: 300, activityShare: 0.4, manualTargetKcal: nil,
                                     tracksWithoutGuide: false, readinessYes: ["heartCondition", "pregnancy"],
                                     preferredActivityIDs: ["walking", "yoga"], equipment: ["bands", "mat"],
                                     mobility: ["lowImpactOnly"], updatedAt: Self.t0))
        context.insert(FoodRecord(id: Self.kimchiID, name: "김치찌개, 집밥", foodGroup: "vegetables", servingLabel: "1 \"bowl\"",
                                  gramsPerServing: 300, energyKcalPer100g: 1234.5, proteinGPer100g: 6.5, source: "userCreated",
                                  isFavorite: true, createdAt: Self.t0))
        context.insert(FoodRecord(name: "Plain rice", foodGroup: "grains", servingLabel: "1 bowl", gramsPerServing: 210,
                                  energyKcalPer100g: 130, source: "userCreated", createdAt: Self.t0.addingTimeInterval(60)))
        context.insert(MealEntryRecord(id: Self.mealID, foodID: Self.kimchiID, foodName: "김치찌개, 집밥", foodGroup: "vegetables",
                                       mealType: "dinner", consumedAt: Self.t0, dayKey: "2027-01-15", quantity: 1.5,
                                       unitLabel: "1 \"bowl\"", grams: 450, energyKcal: 5555.25, proteinG: 29.25, carbsG: nil,
                                       fatG: 12, fiberG: nil, source: "userCreated", createdAt: Self.t0))
        context.insert(MealEntryRecord(id: Self.deletedMealID, foodID: nil, foodName: "Removed snack", foodGroup: "fruit",
                                       mealType: "snack", consumedAt: Self.t0.addingTimeInterval(3600), dayKey: "2027-01-15",
                                       quantity: 1, unitLabel: "1 piece", grams: 100, energyKcal: 52, source: "verified",
                                       createdAt: Self.t0, deletedAt: Self.t0.addingTimeInterval(7200)))
        context.insert(ActivityLogRecord(id: Self.activityID, activityTypeID: "walking", startAt: Self.t0, dayKey: "2027-01-15",
                                         durationMinutes: 30, intensity: "moderate", met: 3.5, energyKcal: nil,
                                         energySource: "manualMET", catalogVersion: "nuri-met-2026.1", createdAt: Self.t0))
        context.insert(ActivityLogRecord(id: Self.deletedActivityID, activityTypeID: "yoga", startAt: Self.t0.addingTimeInterval(86_400),
                                         dayKey: "2027-01-16", durationMinutes: 45.5, intensity: "light", met: 2.5, energyKcal: 120.75,
                                         energySource: "device", catalogVersion: "nuri-met-2026.1", createdAt: Self.t0,
                                         deletedAt: Self.t0.addingTimeInterval(90_000)))
        context.insert(ConsentEventRecord(kind: "withdrawn", adultConfirmed: true, healthDataConsented: false, analyticsOptIn: false,
                                          consentVersion: "2026-10-10", localeIdentifier: "ko_KR", recordedAt: Self.t0.addingTimeInterval(10)))
        context.insert(ConsentEventRecord(kind: "granted", adultConfirmed: true, healthDataConsented: true, analyticsOptIn: true,
                                          consentVersion: "2026-10-10", localeIdentifier: "ko_KR", recordedAt: Self.t0))
        try context.save()
    }

    @Test func mealCSVRowsEqualTheInsertedSnapshotIncludingSoftDeletedRows() throws {
        let c = try container()
        try populate(c.mainContext)
        let files = try DataExport.files(from: c.mainContext, exportedAt: Self.exportedAt)

        let rows = parseCSV(try text(file(files, "meal_entries.csv")))
        #expect(rows.count == 3)
        #expect(rows[0].joined(separator: ",") == Self.mealsHeader)
        #expect(rows[1] == [Self.mealID.uuidString, "2027-01-15T08:00:00Z", "2027-01-15", "dinner", "김치찌개, 집밥", "vegetables",
                            "1.5", "1 \"bowl\"", "450", "5555.25", "29.25", "", "12", "", "userCreated", ""])
        // Soft-deleted rows stay in the export, carrying deleted_at.
        #expect(rows[2] == [Self.deletedMealID.uuidString, "2027-01-15T09:00:00Z", "2027-01-15", "snack", "Removed snack", "fruit",
                            "1", "1 piece", "100", "52", "", "", "", "", "verified", "2027-01-15T10:00:00Z"])
    }

    @Test func foodCSVRowsAndKoreanNamesRoundTripThroughUTF8() throws {
        let c = try container()
        try populate(c.mainContext)
        let files = try DataExport.files(from: c.mainContext, exportedAt: Self.exportedAt)
        let foods = try file(files, "foods.csv")

        // The bytes are UTF-8 and a reader gets the Korean name back unchanged.
        #expect(String(decoding: foods.data, as: UTF8.self).contains("김치찌개"))
        let rows = parseCSV(try text(foods))
        #expect(rows.count == 3)
        #expect(rows[0].joined(separator: ",") == Self.foodsHeader)
        #expect(rows[1] == [Self.kimchiID.uuidString, "김치찌개, 집밥", "vegetables", "1 \"bowl\"", "300", "1234.5", "6.5", "", "", "",
                            "userCreated", "true", "2027-01-15T08:00:00Z"])
        #expect(rows[2][1] == "Plain rice")
        #expect(rows[2][6...9] == ["", "", "", ""])
        #expect(rows[2][11] == "false")
        #expect(rows[2][12] == "2027-01-15T08:01:00Z")
    }

    @Test func activityCSVRowsIncludeSoftDeletedRows() throws {
        let c = try container()
        try populate(c.mainContext)
        let files = try DataExport.files(from: c.mainContext, exportedAt: Self.exportedAt)

        let rows = parseCSV(try text(file(files, "activities.csv")))
        #expect(rows.count == 3)
        #expect(rows[0].joined(separator: ",") == Self.activitiesHeader)
        #expect(rows[1] == [Self.activityID.uuidString, "2027-01-15T08:00:00Z", "2027-01-15", "walking", "30", "moderate", "3.5", "",
                            "manualMET", "nuri-met-2026.1", ""])
        #expect(rows[2] == [Self.deletedActivityID.uuidString, "2027-01-16T08:00:00Z", "2027-01-16", "yoga", "45.5", "light", "2.5",
                            "120.75", "device", "nuri-met-2026.1", "2027-01-16T09:00:00Z"])
    }

    @Test func profileJSONCarriesTheDraftFieldsAsRawValues() throws {
        let c = try container()
        try populate(c.mainContext)
        let files = try DataExport.files(from: c.mainContext, exportedAt: Self.exportedAt)

        let profile = try #require(try JSONSerialization.jsonObject(with: file(files, "profile.json").data, options: [.fragmentsAllowed]) as? [String: Any])
        #expect(profile["birthYear"] as? Int == 1990)
        #expect(profile["sex"] as? String == "female")
        #expect(profile["heightCm"] as? Double == 165.5)
        #expect(profile["weightKg"] as? Double == 58.25)
        #expect(profile["activityLevel"] as? String == "moderatelyActive")
        #expect(profile["goal"] as? String == "gradualLoss")
        #expect(profile["unitSystem"] as? String == "metric")
        #expect(profile["bmiStandard"] as? String == "asianPacific")
        #expect(profile["lossDeficitKcal"] as? Double == 300)
        #expect(profile["activityShare"] as? Double == 0.4)
        #expect(profile["manualTargetKcal"] is NSNull)
        #expect(profile["tracksWithoutGuide"] as? Bool == false)
        #expect(profile["readinessYes"] as? [String] == ["heartCondition", "pregnancy"])
        #expect(profile["preferredActivityIDs"] as? [String] == ["walking", "yoga"])
        #expect(profile["equipment"] as? [String] == ["bands", "mat"])
        #expect(profile["mobility"] as? [String] == ["lowImpactOnly"])
    }

    @Test func fullBackupDecodesWithMatchingCountsAndNullsForMissingOptionals() throws {
        let c = try container()
        try populate(c.mainContext)
        let files = try DataExport.files(from: c.mainContext, exportedAt: Self.exportedAt)
        let data = try file(files, "full_backup.json").data

        let backup = try JSONDecoder.iso.decode(FullBackupDTO.self, from: data)
        #expect(backup.schemaVersion == 1)
        #expect(backup.exportedAt == Self.exportedAt)
        #expect(backup.profile?.birthYear == 1990)
        #expect(backup.foods.count == 2)
        #expect(backup.mealEntries.count == 2)
        #expect(backup.activities.count == 2)
        #expect(backup.consentEvents.count == 2)
        #expect(backup.foods.first?.name == "김치찌개, 집밥")
        #expect(backup.mealEntries.first?.foodID == Self.kimchiID)
        #expect(backup.mealEntries.first?.energyKcal == 5555.25)
        #expect(backup.mealEntries.last?.deletedAt == Self.t0.addingTimeInterval(7200))

        // Missing optionals are explicit nulls (the key is present), not omitted.
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let meals = try #require(object["mealEntries"] as? [[String: Any]])
        #expect(meals[0]["carbsG"] is NSNull)
        #expect(meals[0]["deletedAt"] is NSNull)
        #expect(meals[1]["foodID"] is NSNull)
        let activities = try #require(object["activities"] as? [[String: Any]])
        #expect(activities[0]["energyKcal"] is NSNull)
        let foods = try #require(object["foods"] as? [[String: Any]])
        #expect(foods[1]["proteinGPer100g"] is NSNull)
    }

    @Test func consentHistoryIsExportedInRecordedAtOrder() throws {
        let c = try container()
        try populate(c.mainContext)
        let files = try DataExport.files(from: c.mainContext, exportedAt: Self.exportedAt)

        let events = try JSONDecoder.iso.decode([ConsentEventDTO].self, from: file(files, "consent_events.json").data)
        #expect(events.map(\.kind) == ["granted", "withdrawn"])
        #expect(events.map(\.recordedAt) == [Self.t0, Self.t0.addingTimeInterval(10)])
        #expect(events[0].localeIdentifier == "ko_KR")
        #expect(events[0].analyticsOptIn)
        let backup = try JSONDecoder.iso.decode(FullBackupDTO.self, from: file(files, "full_backup.json").data)
        #expect(backup.consentEvents == events)
    }

    @Test func rowsAreOrderedDeterministicallyRegardlessOfInsertionOrder() throws {
        let c = try container()
        let context = c.mainContext
        for (index, minutes) in [30, 10, 20].enumerated() {
            context.insert(MealEntryRecord(foodID: nil, foodName: "meal \(index)", foodGroup: "grains", mealType: "lunch",
                                           consumedAt: Self.t0.addingTimeInterval(Double(minutes) * 60), dayKey: "2027-01-15",
                                           quantity: 1, unitLabel: "1", grams: 1, energyKcal: 1, source: "userCreated"))
        }
        try context.save()
        let files = try DataExport.files(from: context, exportedAt: Self.exportedAt)
        let names = parseCSV(try text(file(files, "meal_entries.csv"))).dropFirst().map { $0[4] }
        #expect(names == ["meal 1", "meal 2", "meal 0"])
    }

    // MARK: Number and date formats

    @Test func numbersAreLocaleIndependent() throws {
        let c = try container()
        let context = c.mainContext
        context.insert(MealEntryRecord(foodID: nil, foodName: "Big", foodGroup: "grains", mealType: "lunch", consumedAt: Self.t0,
                                       dayKey: "2027-01-15", quantity: 1234.5, unitLabel: "1", grams: 1_234_567.25, energyKcal: 1234.5,
                                       source: "userCreated"))
        try context.save()
        let files = try DataExport.files(from: context, exportedAt: Self.exportedAt)

        let row = try #require(parseCSV(try text(file(files, "meal_entries.csv"))).dropFirst().first)
        #expect(row[6] == "1234.5") // quantity
        #expect(row[8] == "1234567.25") // grams: no grouping separator
        #expect(row[9] == "1234.5") // energy_kcal
        let json = try text(file(files, "full_backup.json"))
        #expect(json.contains("1234.5"))
        #expect(json.contains("1234567.25"))
    }

    @Test func datesAreISO8601UTCAndAgreeBetweenCSVAndJSON() throws {
        let c = try container()
        let context = c.mainContext
        let fractional = Date(timeIntervalSince1970: 1_800_000_000.75)
        context.insert(MealEntryRecord(foodID: nil, foodName: "Frac", foodGroup: "grains", mealType: "lunch", consumedAt: fractional,
                                       dayKey: "2027-01-15", quantity: 1, unitLabel: "1", grams: 1, energyKcal: 1, source: "userCreated"))
        try context.save()
        let files = try DataExport.files(from: context, exportedAt: Self.exportedAt)

        let row = try #require(parseCSV(try text(file(files, "meal_entries.csv"))).dropFirst().first)
        #expect(row[1] == "2027-01-15T08:00:00Z")
        let object = try #require(try JSONSerialization.jsonObject(with: file(files, "full_backup.json").data) as? [String: Any])
        let meals = try #require(object["mealEntries"] as? [[String: Any]])
        #expect(meals[0]["consumedAt"] as? String == row[1])
        #expect(object["exportedAt"] as? String == "2027-01-16T11:46:40Z")
    }

    @Test func aNonFiniteValueNeverStopsAnExport() throws {
        // SQLite cannot hold NaN (it comes back as 0), but it does hold infinity; JSON has no literal for it.
        let c = try container()
        let context = c.mainContext
        context.insert(MealEntryRecord(foodID: nil, foodName: "Corrupt", foodGroup: "grains", mealType: "lunch", consumedAt: Self.t0,
                                       dayKey: "2027-01-15", quantity: 1, unitLabel: "1", grams: 1, energyKcal: .infinity, source: "userCreated"))
        try context.save()
        let files = try DataExport.files(from: context, exportedAt: Self.exportedAt)
        #expect(files.count == 6)
        let row = try #require(parseCSV(try text(file(files, "meal_entries.csv"))).dropFirst().first)
        #expect(row[9] == "Infinity")
        let backup = try text(file(files, "full_backup.json"))
        #expect(backup.contains("\"energyKcal\" : \"Infinity\""))
    }

    // MARK: Writing

    @Test func writeCreatesTheFilesWithExactNamesAndReturnsTheirURLs() throws {
        let c = try container()
        try populate(c.mainContext)
        let files = try DataExport.files(from: c.mainContext, exportedAt: Self.exportedAt)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("nuri-export-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let urls = try DataExport.write(files, to: directory)

        #expect(urls.map(\.lastPathComponent) == Self.fileNames)
        #expect(urls.allSatisfy { $0.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL })
        for (file, url) in zip(files, urls) {
            #expect(try Data(contentsOf: url) == file.data)
        }
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(Set(onDisk) == Set(Self.fileNames))
    }

    @Test func writeOverwritesAnEarlierExportInTheSameDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("nuri-export-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try DataExport.write([ExportFile(name: "a.csv", data: Data("old".utf8))], to: directory)
        let urls = try DataExport.write([ExportFile(name: "a.csv", data: Data("new".utf8))], to: directory)
        #expect(try String(contentsOf: try #require(urls.first), encoding: .utf8) == "new")
    }
}

extension JSONDecoder {
    static var iso: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
