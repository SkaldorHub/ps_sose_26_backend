import Fluent   

// Migration to create the "Team" table in the database, which represents teams participating in games
struct CreateTeam: Migration {  
    // Creates the "Team" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Team.schema)
            .id()
            .field("name", .string)
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .create()
    }

    // Deletes the "Team" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Team.schema).delete()
    }
}