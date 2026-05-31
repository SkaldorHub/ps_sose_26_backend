import Fluent

/// Migration to create the "photos" table in the database, storing photos taken during a round
struct CreatePhoto: AsyncMigration {

    // Creates the "photos" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Photo.schema)
            .id()
            .field("photographer_id", .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field("round_id", .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field("photo_url", .string, .required)
            .field("latitude", .double, .required)
            .field("longitude", .double, .required)
            // hint is optional, the photographer may choose not to provide one
            .field("hint", .string)
            .create()
    }

    // Deletes the "photos" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Photo.schema).delete()
    }
}