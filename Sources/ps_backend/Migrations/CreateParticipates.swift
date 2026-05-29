import Fluent   

// Migration to create the "participates" table in the database, linking users to games and teams
struct CreateParticipates: Migration {      
    // Creates the "participates" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Participates.schema)
            .id()
            .field("game_id", .uuid, .required, .references(Game.schema, "id", onDelete: .restrict))
            .field("team_id", .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            .field("isWinner", .bool, .required)
            .unique(on: "game_id", "team_id") // Ensure a team can only participate once in a game
            .create()
    }

    // Deletes the "participates" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Participates.schema).delete()
    }
}