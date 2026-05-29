import Fluent

// Migration to create the "game" table in the database
struct CreateGame: Migration {

    // Creates the "game" table with the specified fields
    func prepare(on database: Database) async throws {
        try await database.schema(Game.schema)
            .id()
            .field("state", .string, .required)
            .field("host_id", .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field("started_at", .datetime)
            .field("finished_at", .datetime)
            .create()
    }

    // Deletes the "game" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Game.schema).delete()
    }
}