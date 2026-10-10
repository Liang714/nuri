import Foundation
import SwiftData

/// "Delete everything": the one place that removes every record, including the consent history and any export copies.
@MainActor
public enum DataWiper {
    public static func deleteEverything(in context: ModelContext) throws {
        // Export copies are personal data too: they go with everything else.
        try DataExport.removeExportDirectory()
        // `delete(model:)` works on the store, so drop pending (unsaved) changes first; otherwise the trailing
        // save would write an unsaved insert back after the wipe.
        context.rollback()
        try context.delete(model: ProfileRecord.self)
        try context.delete(model: FoodRecord.self)
        try context.delete(model: MealEntryRecord.self)
        try context.delete(model: ActivityLogRecord.self)
        try context.delete(model: ConsentEventRecord.self)
        try context.save()
    }
}
