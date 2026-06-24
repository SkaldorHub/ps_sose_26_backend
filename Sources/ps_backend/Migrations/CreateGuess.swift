import Fluent

struct CreateGuess: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(Guess.schema)
            .id()
            .field(Guess.FieldKeys.userID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field(Guess.FieldKeys.roundID, .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field(Guess.FieldKeys.latitude, .double, .required)
            .field(Guess.FieldKeys.longitude, .double, .required)
            .field(Guess.FieldKeys.distance, .double)
            .field(Guess.FieldKeys.viewingDeadline, .datetime, .required)
            .field(Guess.FieldKeys.guessDeadline, .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Guess.schema).delete()
    }
}
