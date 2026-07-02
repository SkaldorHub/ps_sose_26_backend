import Fluent

struct CreateRound: AsyncMigration {

    func prepare(on database: any Database) async throws {
        let currentPhase = try await database.enum("current_phase")
            .case(Round.CurrentPhase.upload.rawValue)
            .case(Round.CurrentPhase.guess.rawValue)
            .case(Round.CurrentPhase.calculateResults.rawValue)
            .create()

        try await database.schema(Round.schema)
            .id()
            .field(Round.FieldKeys.gameID, .uuid, .required, .references(Game.schema, "id", onDelete: .restrict))
            .field(Round.FieldKeys.roundNumber, .int, .required)
            .field(Round.FieldKeys.currentPhase, currentPhase, .required)
            .field(Round.FieldKeys.deadline, .datetime)
            .create()

        try await database.schema(RoundPhotographer.schema)
            .id()
            .field(RoundPhotographer.FieldKeys.roundID, .uuid, .required, .references(Round.schema, "id", onDelete: .cascade))
            .field(RoundPhotographer.FieldKeys.teamID, .uuid, .required, .references(Team.schema, "id", onDelete: .restrict))
            .field(RoundPhotographer.FieldKeys.userID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .unique(on: RoundPhotographer.FieldKeys.roundID, RoundPhotographer.FieldKeys.teamID)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(RoundPhotographer.schema).delete()
        try await database.schema(Round.schema).delete()
        try await database.enum("current_phase").delete()
    }
}