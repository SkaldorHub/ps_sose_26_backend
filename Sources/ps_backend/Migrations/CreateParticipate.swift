import Fluent   

/// Migration to create the "participate" table in the database, linking teams to games and indicating whether they are winners
struct CreateParticipate: AsyncMigration {    

    // Creates the "participate" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Participate.schema)
            .id()
            .field(Participate.FieldKeys.gameID, .uuid, .required, .references(Game.schema, "id", onDelete: .restrict))
            .field(Participate.FieldKeys.teamID, .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            // combination of game_id and team_id must be unique to prevent duplicate entries for the same team in the same game
            .unique(on: Participate.FieldKeys.gameID, Participate.FieldKeys.teamID)
            .field(Participate.FieldKeys.isWinner, .bool, .required, .sql(.default(false)))
            .create()
    }

    // Deletes the "participate" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Participate.schema).delete()
    }
}