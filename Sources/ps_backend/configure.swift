import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    func require(_ key: String) -> String {
        guard let value = Environment.get(key) else {
            fatalError("Umgebungsvariable '\(key)' ist nicht gesetzt")
        }
        return value
    }

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: require("DATABASE_HOST"),
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: require("DATABASE_USERNAME"),
        password: require("DATABASE_PASSWORD"),
        database: require("DATABASE_NAME"),
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration), at: .beginning)

    // add migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateTeam())
    app.migrations.add(CreateGame())
    app.migrations.add(CreateTeamMember())
    app.migrations.add(CreateRound())
    app.migrations.add(CreateParticipate())
    app.migrations.add(CreatePhoto())
    app.migrations.add(CreateGuess())
    app.migrations.add(CreateRoundResult())
    app.migrations.add(AddGameFields())

    // register routes
    try routes(app)
}
