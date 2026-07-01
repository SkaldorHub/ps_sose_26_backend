import Fluent

struct CreateRoundResult: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(RoundResult.schema)
            .id()
            .field(RoundResult.FieldKeys.roundID, .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field(RoundResult.FieldKeys.teamID, .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            .unique(on: RoundResult.FieldKeys.roundID, RoundResult.FieldKeys.teamID)
            .field(RoundResult.FieldKeys.teamPoints, .int, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(RoundResult.schema).delete()
    }
}
