import Fluent   

/// Migration to create the "round" table in the database, which represents rounds in a game
struct CreateRound: AsyncMigration {    

    // Creates the "round" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        
        // Creates an enum type for the "current_phase" field in the "round" table
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
    }

    // Deletes the "round" table if the migration is reverted
    func revert(on database: Database) async throws {
         try await database.schema(Round.schema).delete()
        try await database.enum("current_phase").delete()
    }
}