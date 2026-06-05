import Fluent

/// Migration to create the "round_results" table in the database
struct CreateRoundResult: AsyncMigration {

    // Creates the "round_results" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(RoundResult.schema)
            .id()
            .field(RoundResult.FieldKeys.roundID, .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field(RoundResult.FieldKeys.teamID, .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            // combination of round_id and team_id must be unique to prevent duplicate entries for the same team in the same round
            .unique(on: RoundResult.FieldKeys.roundID, RoundResult.FieldKeys.teamID)
            .field(RoundResult.FieldKeys.teamPoints, .int, .required)
            .create()
    }

    // Deletes the "round_results" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(RoundResult.schema).delete()
    }
}