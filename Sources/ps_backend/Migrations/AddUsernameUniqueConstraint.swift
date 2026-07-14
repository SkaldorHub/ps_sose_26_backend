import Fluent

/// Ohne diesen Constraint können zwei parallele register()-Requests mit demselben Usernamen
/// beide den Application-Level-Check (findUser == nil) passieren und beide einen Account
/// anlegen (TOCTOU) - login() findet dann per .first() nur zufällig einen der beiden.
struct AddUsernameUniqueConstraint: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(User.schema)
            .unique(on: User.FieldKeys.username)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(User.schema)
            .deleteUnique(on: User.FieldKeys.username)
            .update()
    }
}
