import Fluent

/// Migration to create the "round_results" table in the database
struct CreateRoundResult: AsyncMigration {

    // Creates the "round_results" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(RoundResult.schema)
            .id()
            .field("round_id", .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field("team_id", .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            // combination of round_id and team_id must be unique to prevent duplicate entries for the same team in the same round
            .unique(on: "round_id", "team_id") 
            .field("team_points", .int, .required)
            .create()
    }

    // Deletes the "round_results" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(RoundResult.schema).delete()
    }
}