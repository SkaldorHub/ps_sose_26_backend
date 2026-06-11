import Fluent   
import Vapor

/// This model represents a team in the database, including the team name and its association with a user and game participations.
final class Team: Model, Content, @unchecked Sendable {

    // A collection of field keys for the Team model
    struct FieldKeys {
        static var name: FieldKey { "name" }
    }

    static let schema = "teams"

    // Unique identifier for each team
    @ID(key: .id)
    var id: UUID?

    // The name of the team
    @Field(key: Team.FieldKeys.name)
    var name: String

    // The games this team is participating in
    @Children(for: \.$team)
    var participates: [Participate]

    // The round results associated with this team
    @Children(for: \.$team) 
    var roundResults: [RoundResult]
    
    // The team members associated with this team
    @Children(for: \.$team)
    var teamMembers: [TeamMember]

    // Initializer for the Team model
    init() {}
    
    // Initializer for the Team model with parameters for id and name
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}