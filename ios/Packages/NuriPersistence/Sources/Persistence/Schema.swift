// Before shipping a V2 that changes any model: freeze V1's model definitions as nested types under `NuriSchemaV1`
// (Apple's VersionedSchema pattern: each version owns its own @Model classes), point the app at the new top-level
// models, and add a `MigrationStage` to `NuriMigrationPlan.stages`. Today the models below are V1 and the plan has
// no stages, which is only correct while V1 is the only version that has ever shipped.
import Foundation
import SwiftData

public enum NuriSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, FoodRecord.self, MealEntryRecord.self, ActivityLogRecord.self, ConsentEventRecord.self]
    }
}

public enum NuriMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [NuriSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum NuriStore {
    /// The app's store. On iOS, `url` should point inside Application Support with file protection enabled by the caller.
    @MainActor
    public static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NuriSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, migrationPlan: NuriMigrationPlan.self, configurations: [configuration])
    }
}
