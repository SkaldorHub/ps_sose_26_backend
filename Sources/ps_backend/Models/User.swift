import Fluent
import Vapor

/// Model representing a user in the database
final class User: Model, Content, @unchecked Sendable {

    // A collection of field keys for the User model
    struct FieldKeys {
        static var username: FieldKey { "username" }
        static var passwordHash: FieldKey { "password_hash" }
    }

    static let schema = "users"

    // Unique identifier for each user
    @ID(key: .id)
    var id: UUID?

    // Username of the user
    @Field(key: User.FieldKeys.username)
    var username: String

    // Password hash for the user's password
    @Field(key: User.FieldKeys.passwordHash)
    var passwordHash: String

    // Relationship to the games hosted by the user
    @Children(for: \.$host)
    var games: [Game]

    // Relationship to the guesses made by the user
    @Children(for: \.$user)
    var guesses: [Guess]
    
    // Relationship to the photos taken by the user
    @Children(for: \.$photographer)
    var photos: [Photo]

    // Relationship to the team members associated with the user
    @Children(for: \.$user)
    var teamMembers: [TeamMember]

    // Initializer for the User model
    init() {}

    // Initializer for the User model with parameters for id, username, and passwordHash
   init(id: UUID? = nil, username: String, passwordHash: String) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
    }
}