import Fluent

struct CreateParticipate: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(Participate.schema)
            .id()
            .field(Participate.FieldKeys.gameID, .uuid, .required, .references(Game.schema, "id", onDelete: .restrict))
            .field(Participate.FieldKeys.teamID, .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            .unique(on: Participate.FieldKeys.gameID, Participate.FieldKeys.teamID)
            .field(Participate.FieldKeys.isWinner, .bool, .required, .sql(.default(false)))
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Participate.schema).delete()
    }
}
