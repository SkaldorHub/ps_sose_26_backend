import Fluent   

/// Migration to create the "guesses" table in the database, linking users to rounds and storing their guessed location
struct CreateGuess: AsyncMigration {    

    // Creates the "guesses" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Guess.schema)
            .id()
            .field(Guess.FieldKeys.userID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field(Guess.FieldKeys.roundID, .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field(Guess.FieldKeys.latitude, .double, .required)
            .field(Guess.FieldKeys.longitude, .double, .required)
            // distance and points are calculated after the guess is made
            .field(Guess.FieldKeys.distance, .double)
            .field(Guess.FieldKeys.points, .int)
            .field(Guess.FieldKeys.viewingDeadline, .datetime, .required)
            .field(Guess.FieldKeys.guessDeadline, .datetime, .required)
            .create()
    }

    // Deletes the "guesses" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Guess.schema).delete()
    }
}