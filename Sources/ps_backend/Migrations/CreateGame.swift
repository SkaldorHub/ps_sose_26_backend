import Fluent

struct CreateGame: AsyncMigration {

    /// Historisches Feld, seit RenamePhaseDurationFields nicht mehr Teil von Game.FieldKeys.
    private static let roundDurationHours: FieldKey = "round_duration_hours"

    func prepare(on database: any Database) async throws {
        let gameState = try await database.enum("state")
            .case(Game.State.lobby.rawValue)
            .case(Game.State.running.rawValue)
            .case(Game.State.gameOver.rawValue)
            .create()

        try await database.schema(Game.schema)
            .id()
            .field(Game.FieldKeys.hostID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field(Game.FieldKeys.state, gameState, .required)
            .field(Game.FieldKeys.code, .string, .required)
            .field(Game.FieldKeys.totalRounds, .int, .required)
            .field(Game.FieldKeys.maxPlayers, .int, .required)
            .field(Self.roundDurationHours, .int, .required)
            .field(Game.FieldKeys.photoViewSeconds, .int, .required)
            .field(Game.FieldKeys.startedAt, .datetime)
            .field(Game.FieldKeys.finishedAt, .datetime)
            .field(Game.FieldKeys.createdAt, .datetime)
            .unique(on: Game.FieldKeys.code)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Game.schema).delete()
        try await database.enum("state").delete()
    }
}
