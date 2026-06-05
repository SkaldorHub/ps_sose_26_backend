import Fluent

/// Migration to create the "game" table in the database
struct CreateGame: AsyncMigration {

    // Creates the "game" table with the specified fields
    func prepare(on database: Database) async throws {
        
        // Creates an enum type for the "game_state" field in the "game" table
       let gameState = try await database.enum(Game.FieldKeys.state)
            .case(Game.State.lobby.rawValue)
            .case(Game.State.running.rawValue)
            .case(Game.State.gameOver.rawValue)
            .create()

        // Creates the "game" table with the specified fields and relationships
        try await database.schema(Game.schema)
            .id()
            .field(Game.FieldKeys.hostID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field(Game.FieldKeys.startedAt, .datetime)
            .field(Game.FieldKeys.finishedAt, .datetime)
            .field(Game.FieldKeys.state, gameState, .required)
            .create()
    }

    // Deletes the "game" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.enum(Game.FieldKeys.state).delete()
        try await database.schema(Game.schema).delete()
    }
}