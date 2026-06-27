import Fluent

struct AddGameFields: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(Game.schema)
            .field(Game.FieldKeys.name, .string, .required, .sql(.default("")))
            .field(Game.FieldKeys.uploadPhaseHours, .int, .required, .sql(.default(24)))
            .field(Game.FieldKeys.guessingPhaseHours, .int, .required, .sql(.default(24)))
            .field(Game.FieldKeys.setMarkerSeconds, .int, .required, .sql(.default(300)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Game.schema)
            .deleteField(Game.FieldKeys.name)
            .deleteField(Game.FieldKeys.uploadPhaseHours)
            .deleteField(Game.FieldKeys.guessingPhaseHours)
            .deleteField(Game.FieldKeys.setMarkerSeconds)
            .update()
    }
}
