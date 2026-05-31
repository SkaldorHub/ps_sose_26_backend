import Fluent
import Vapor

/// Model representing a user in the database
final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"
    // Unique identifier for each user
    @ID(key: .id)
    var id: UUID?

    // Username of the user
    @Field(key: "username")
    var username: String

    // Password hash for the user's password
    @Field(key: "password_hash")
    var passwordHash: String

    // Relationship to the games hosted by the user
    @Children(for: \.$host)
    var games: [Game]

    // Relationship to the teams the user is part of
    @Children(for: \.$user)
    var teams: [Team]

    // Relationship to the guesses made by the user
    @Children(for: \.$user)
    var guesses: [Guess]
    
    // Relationship to the photos taken by the user
    @Children(for: \.$photographer)
    var photos: [Photo]

    // Initializer for the User model
    init() {}

    // Initializer to create a new User instance with the provided username and password hash
    init(id: UUID? = nil, username: String, passwordHash: String) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
    }
}