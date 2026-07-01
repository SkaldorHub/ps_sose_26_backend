import Fluent

struct CreateTeamMember: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(TeamMember.schema)
            .id()
            .field(TeamMember.FieldKeys.teamID, .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            .field(TeamMember.FieldKeys.userID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field(TeamMember.FieldKeys.gameID, .uuid, .required, .references(Game.schema, "id", onDelete: .restrict))
            .field(TeamMember.FieldKeys.joinedAt, .datetime)
            .unique(on: TeamMember.FieldKeys.userID, TeamMember.FieldKeys.gameID)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(TeamMember.schema).delete()
    }
}
