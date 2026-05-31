import Fluent   

/// Migration to create the "participates" table in the database, linking teams to games and indicating whether they are winners
struct CreateParticipates: AsyncMigration {    

    // Creates the "participates" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Participates.schema)
            .id()
            .field("game_id", .uuid, .required, .references(Game.schema, "id", onDelete: .restrict))
            .field("team_id", .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            // combination of game_id and team_id must be unique to prevent duplicate entries for the same team in the same game
            .unique(on: "game_id", "team_id") 
            .field("isWinner", .bool, .required, .sql(.default(false)))
            .create()
    }

    // Deletes the "participates" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Participates.schema).delete()
    }
}