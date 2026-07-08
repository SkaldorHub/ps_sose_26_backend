import Fluent

struct AddGameFields: AsyncMigration {

    /// Historische Felder, seit RenamePhaseDurationFields nicht mehr Teil von Game.FieldKeys.
    private static let uploadPhaseHours: FieldKey = "upload_phase_hours"
    private static let guessingPhaseHours: FieldKey = "guessing_phase_hours"

    func prepare(on database: any Database) async throws {
        try await database.schema(Game.schema)
            .field(Game.FieldKeys.name, .string, .required, .sql(.default("")))
            .field(Self.uploadPhaseHours, .int, .required, .sql(.default(24)))
            .field(Self.guessingPhaseHours, .int, .required, .sql(.default(24)))
            .field(Game.FieldKeys.setMarkerSeconds, .int, .required, .sql(.default(300)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Game.schema)
            .deleteField(Game.FieldKeys.name)
            .deleteField(Self.uploadPhaseHours)
            .deleteField(Self.guessingPhaseHours)
            .deleteField(Game.FieldKeys.setMarkerSeconds)
            .update()
    }
}
