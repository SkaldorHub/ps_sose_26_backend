import Fluent
import Vapor

/// This model represents a team member in the database, including the association between a user and a team.
final class TeamMember: Model, Content, @unchecked Sendable {   
    static let schema = "team_members"

    // Unique identifier for each team member entry
    @ID(key: .id)
    var id: UUID?

    // The team this member belongs to
    @Parent(key: "team_id")
    var team: Team

    // The user associated with this team member entry
    @Parent(key: "user_id")
    var user: User

    // The game associated with this team member entry
    @Parent(key: "game_id")
    var game: Game

    // Initializer for the TeamMember model
    init() {}
    
    // Initializer for the TeamMember model with parameters for id, teamID, userID, and gameID
    init(id: UUID? = nil, teamID: UUID, userID: UUID, gameID: UUID) {
        self.id = id
        self.$team.id = teamID
        self.$user.id = userID
        self.$game.id = gameID
    }
}