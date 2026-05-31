import Fluent   

/// Migration to create the "round" table in the database, which represents rounds in a game
struct CreateRound: AsyncMigration {    

    // Creates the "round" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
       let currentPhase = try await database.enum("current_phase")
            .case(Round.CurrentPhase.uploading.rawValue)
            .case(Round.CurrentPhase.viewingPhotos.rawValue)
            .case(Round.CurrentPhase.guessing.rawValue)
            .case(Round.CurrentPhase.calculatingResults.rawValue)
            .case(Round.CurrentPhase.roundOver.rawValue)
            .create()

        try await database.schema(Round.schema)
            .id()
            .field("game_id", .uuid, .required, .references(Game.schema, "id", onDelete: .restrict))
            .field("round_number", .int, .required)
            .field("current_phase", currentPhase, .required)
            .field("deadline", .datetime)
            .create()
    }

    // Deletes the "round" table if the migration is reverted
    func revert(on database: Database) async throws {
         try await database.schema(Round.schema).delete()
        try await database.enum("current_phase").delete()
    }
}