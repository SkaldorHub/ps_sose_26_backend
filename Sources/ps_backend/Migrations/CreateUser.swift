import Fluent

// Migration to create the "user" table in the database
struct CreateUser: Migration {

    // Creates the "user" table with the specified fields
    func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field("username", .string, .required)
            .field("passwordHash", .string, .required)
            .create()
    }

    // Deletes the "user" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
}