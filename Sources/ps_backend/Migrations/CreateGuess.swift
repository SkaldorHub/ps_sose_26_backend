import Fluent   

/// Migration to create the "guesses" table in the database, linking users to rounds and storing their guessed location
struct CreateGuess: AsyncMigration {    

    // Creates the "guesses" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Guess.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field("round_id", .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field("latitude", .double, .required)
            .field("longitude", .double, .required)
            // distance is calculated after the guess is made
            .field("distance", .double)
            .field("viewing_deadline", .datetime, .required)
            .field("guess_deadline", .datetime, .required)
            .create()
    }

    // Deletes the "guesses" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Guess.schema).delete()
    }
}