import Foundation
import SwiftData

/// "Delete everything": the one place that removes every record, including the consent history.
@MainActor
public enum DataWiper {
    public static func deleteEverything(in context: ModelContext) throws {
        // `delete(model:)` works on the store, so flush pending inserts first or the trailing save would write them back.
        try context.save()
        try context.delete(model: ProfileRecord.self)
        try context.delete(model: FoodRecord.self)
        try context.delete(model: MealEntryRecord.self)
        try context.delete(model: ActivityLogRecord.self)
        try context.delete(model: ConsentEventRecord.self)
        try context.save()
    }
}
