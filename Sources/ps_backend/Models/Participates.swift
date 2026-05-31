import Fluent   
import Vapor

/// This model represents a participation entry linking a team to a game, including whether the team won the game.
final class Participates: Model, Content, @unchecked Sendable {
    static let schema = "participates"

    // Unique identifier for each participation entry
    @ID(key: .id)
    var id: UUID?

    // The game this participation entry is associated with
    @Parent(key: "game_id")
    var game: Game

    // The team participating in the game
    @Parent(key: "team_id")
    var team: Team

    // Whether the team won the game
    @Field(key: "isWinner")
    var isWinner: Bool

    // Initializer for the Participates model
    init() {}
    
    // Initializer for the Participates model with parameters for id, gameID, teamID, and isWinner
    init(id: UUID? = nil, gameID: UUID, teamID: UUID, isWinner: Bool) {
        self.id = id
        self.$game.id = gameID
        self.$team.id = teamID
        self.isWinner = isWinner
    }
}