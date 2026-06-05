import Fluent

/// Migration to create the "photos" table in the database, storing photos taken during a round
struct CreatePhoto: AsyncMigration {

    // Creates the "photos" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Photo.schema)
            .id()
            .field(Photo.FieldKeys.photographerID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field(Photo.FieldKeys.roundID, .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field(Photo.FieldKeys.photoURL, .string, .required)
            .field(Photo.FieldKeys.latitude, .double, .required)
            .field(Photo.FieldKeys.longitude, .double, .required)
            // hint is optional, the photographer may choose not to provide one
            .field(Photo.FieldKeys.hint, .string)
            .create()
    }

    // Deletes the "photos" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Photo.schema).delete()
    }
}