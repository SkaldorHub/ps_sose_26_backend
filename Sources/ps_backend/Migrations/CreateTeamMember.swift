import Fluent

// Migration to create the "team_members" table, linking users to teams within a specific game
struct CreateTeamMember: AsyncMigration {

    // Creates the "team_members" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(TeamMember.schema)
            .id()
            .field(TeamMember.FieldKeys.teamID, .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            .field(TeamMember.FieldKeys.userID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field(TeamMember.FieldKeys.gameID, .uuid, .required, .references(Game.schema, "id", onDelete: .restrict))
            // a user can only be a member of one team per game
            .unique(on: TeamMember.FieldKeys.userID, TeamMember.FieldKeys.gameID)
            .create()
    }

    // Deletes the "team_members" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(TeamMember.schema).delete()
    }
}