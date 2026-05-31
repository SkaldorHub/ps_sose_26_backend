import Fluent   
import Vapor

/// This model represents a team in the database, including the team name and its association with a user and game participations.
final class Team: Model, Content, @unchecked Sendable {
    static let schema = "teams"

    // Unique identifier for each team
    @ID(key: .id)
    var id: UUID?

    // The name of the team
    @Field(key: "name")
    var name: String

    // The user associated with this team
    @Parent(key: "user_id")
    var user: User

    // The games this team is participating in
    @Children(for: \.$team)
    var participates: [Participates]

    // The round results associated with this team
    @Children(for: \.$team) 
    var roundResults: [RoundResult]

    // Initializer for the Team model
    init() {}
    
    // Initializer for the Team model with parameters for id, name, and userId
    init(id: UUID? = nil, name: String, userId: UUID) {
        self.id = id
        self.name = name
        self.$user.id = userId
    }
}