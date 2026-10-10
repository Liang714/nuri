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
