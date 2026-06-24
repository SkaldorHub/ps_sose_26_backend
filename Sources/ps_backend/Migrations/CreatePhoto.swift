import Fluent

struct CreatePhoto: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(Photo.schema)
            .id()
            .field(Photo.FieldKeys.photographerID, .uuid, .required, .references(User.schema, "id", onDelete: .restrict))
            .field(Photo.FieldKeys.roundID, .uuid, .required, .references(Round.schema, "id", onDelete: .restrict))
            .field(Photo.FieldKeys.photoURL, .string, .required)
            .field(Photo.FieldKeys.latitude, .double, .required)
            .field(Photo.FieldKeys.longitude, .double, .required)
            .field(Photo.FieldKeys.hint, .string)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Photo.schema).delete()
    }
}
