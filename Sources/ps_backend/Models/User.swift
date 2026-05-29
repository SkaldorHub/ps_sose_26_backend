import Fluent
import Vapor

// Model representing a user in the database
final class User: Model, Content {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "passwordHash")
    var passwordHash: String

    @Children(for: \.$host)
    var games: [Game]

    @Children(for: \.$user)
    var teams: [Team]
    
    init() {}

    init(id: UUID? = nil, username: String, passwordHash: String) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
    }
}