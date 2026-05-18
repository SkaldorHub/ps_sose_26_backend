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

    // register routes
    try routes(app)
}
