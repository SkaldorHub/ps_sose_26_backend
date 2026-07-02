import Fluent

struct CreateUser: AsyncMigration {

    func prepare(on database: any Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field(User.FieldKeys.username, .string, .required)
            .field(User.FieldKeys.passwordHash, .string, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(User.schema).delete()
    }
}
