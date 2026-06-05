import Fluent   

/// Migration to create the "Team" table in the database, which represents teams participating in games
struct CreateTeam: AsyncMigration {  
    
    // Creates the "Team" table with the specified fields and relationships
    func prepare(on database: Database) async throws {
        try await database.schema(Team.schema)
            .id()
            .field(Team.FieldKeys.name, .string, .required)
            .create()
    }

    // Deletes the "Team" table if the migration is reverted
    func revert(on database: Database) async throws {
        try await database.schema(Team.schema).delete()
    }
}