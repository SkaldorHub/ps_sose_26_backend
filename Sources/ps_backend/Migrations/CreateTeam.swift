import Fluent

struct CreateTeam: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(Team.schema)
            .id()
            .field(Team.FieldKeys.name, .string, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Team.schema).delete()
    }
}
