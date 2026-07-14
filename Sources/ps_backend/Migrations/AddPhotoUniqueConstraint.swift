import Fluent

/// Ohne diesen Constraint können zwei parallele uploadPhoto()-Requests desselben Fotografen für
/// dieselbe Runde beide den Application-Level-Check (kein existierendes Photo) passieren und
/// beide eine Photo-Zeile anlegen (TOCTOU) - welche davon bei der Auswertung herangezogen wird,
/// wäre dann nicht deterministisch.
struct AddPhotoUniqueConstraint: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(Photo.schema)
            .unique(on: Photo.FieldKeys.roundID, Photo.FieldKeys.photographerID)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Photo.schema)
            .deleteUnique(on: Photo.FieldKeys.roundID, Photo.FieldKeys.photographerID)
            .update()
    }
}
