import Fluent   
import Vapor

// Model representing a participation in a game, linking teams to games
final class Participates: Model, Content {
    static let schema = "participates"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "game_id")
    var game: Game

    @Parent(key: "team_id")
    var team: Team

    @Field(key: "isWinner")
    var isWinner: Bool

    init() {}

    init(id: UUID? = nil, gameID: UUID, teamID: UUID, isWinner: Bool) {
        self.id = id
        self.$game.id = gameID
        self.$team.id = teamID
        self.isWinner = isWinner
    }
}