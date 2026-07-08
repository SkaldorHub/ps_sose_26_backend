import Fluent

/// roundDurationHours wurde nirgends mehr gelesen (PhaseScheduler nutzte es fälschlich für die
/// Upload-Phase statt uploadPhaseHours). uploadPhaseHours/guessingPhaseHours werden auf Sekunden
/// umgestellt, damit sie für kurze Demo-Spiele nutzbar sind (siehe LobbyController.createGame).
struct RenamePhaseDurationFields: AsyncMigration {

    private static let roundDurationHours: FieldKey = "round_duration_hours"
    private static let uploadPhaseHours: FieldKey = "upload_phase_hours"
    private static let guessingPhaseHours: FieldKey = "guessing_phase_hours"

    func prepare(on database: any Database) async throws {
        try await database.schema(Game.schema)
            .deleteField(Self.roundDurationHours)
            .deleteField(Self.uploadPhaseHours)
            .deleteField(Self.guessingPhaseHours)
            .field(Game.FieldKeys.uploadPhaseSeconds, .int, .required, .sql(.default(86400)))
            .field(Game.FieldKeys.guessingPhaseSeconds, .int, .required, .sql(.default(86400)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Game.schema)
            .deleteField(Game.FieldKeys.uploadPhaseSeconds)
            .deleteField(Game.FieldKeys.guessingPhaseSeconds)
            .field(Self.roundDurationHours, .int, .required, .sql(.default(24)))
            .field(Self.uploadPhaseHours, .int, .required, .sql(.default(24)))
            .field(Self.guessingPhaseHours, .int, .required, .sql(.default(24)))
            .update()
    }
}
