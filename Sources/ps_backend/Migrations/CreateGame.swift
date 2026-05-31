import Fluent

/// Migration to create the "game" table in the database
struct CreateGame: AsyncMigration {

    // Creates the "game" table with the specified fields
    func prepare(on database: Database) async throws {
        // Creates an enum type for the "game_state" field in the "game" table
       let gameState = try await database.enum("game_state")
            .case(Game.State.lobby.rawValue)
            .case(Game.State.running.rawValue)
            .case(Game.State.gameOver.rawValue)
            .create()

        // Creates the "game" table with the specified fields and relationships
        try await database.schema(Game.schema)
            .id()
            .field("host_id", .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field("started_at", .datetime)
            .field("finished_at", .datetime)
            .field("state", gameState, .required)
            .create()
    }

    // Deletes the "game" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.enum("game_state").delete()
        try await database.schema(Game.schema).delete()
    }
}