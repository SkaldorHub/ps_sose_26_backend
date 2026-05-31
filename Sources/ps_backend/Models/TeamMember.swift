import Fluent
import Vapor

/// This model represents a team member in the database, including the association between a user and a team.
final class TeamMember: Model, Content, @unchecked Sendable {  
    
    // A collection of field keys for the TeamMember model
    struct FieldKeys {
        static var teamID: FieldKey { "team_id" }
        static var userID: FieldKey { "user_id" }
        static var gameID: FieldKey { "game_id" }
    }

    static let schema = "team_members"

    // Unique identifier for each team member entry
    @ID(key: .id)
    var id: UUID?

    // The team this member belongs to
    @Parent(key: TeamMember.FieldKeys.teamID)
    var team: Team

    // The user associated with this team member entry
    @Parent(key: TeamMember.FieldKeys.userID)
    var user: User

    // The game associated with this team member entry
    @Parent(key: TeamMember.FieldKeys.gameID)
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