import Fluent
import Vapor    

/// This model represents the result of a round for a specific team, including the points earned by the team in that round.
final class RoundResult: Model, Content, @unchecked Sendable {
    static let schema = "round_results"

    // Unique identifier for each round result
    @ID(key: .id)
    var id: UUID?

    // The round this result is associated with
    @Parent(key: "round_id")
    var round: Round

    // The team this result is associated with
    @Parent(key: "team_id")
    var team: Team
    
    // The points earned by the team in this round
    @Field(key: "team_points")
    var teamPoints: Int

    // Initializer for the RoundResult model
    init() {}

    // Initializer for the RoundResult model with parameters for id, roundID, teamID, and teamPoints
    init(id: UUID? = nil, roundID: UUID, teamID: UUID, teamPoints: Int) {
        self.id = id
        self.$round.id = roundID
        self.$team.id = teamID
        self.teamPoints = teamPoints
    }
}