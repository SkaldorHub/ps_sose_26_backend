import Fluent
import Vapor    

/// This model represents the result of a round for a specific team, including the points earned by the team in that round.
final class RoundResult: Model, Content, @unchecked Sendable {

    // A collection of field keys for the RoundResult model
    struct FieldKeys {
        static var roundID: FieldKey { "round_id" }
        static var teamID: FieldKey { "team_id" }
        static var teamPoints: FieldKey { "team_points" }
    }

    static let schema = "round_results"

    // Unique identifier for each round result
    @ID(key: .id)
    var id: UUID?

    // The round this result is associated with
    @Parent(key: RoundResult.FieldKeys.roundID)
    var round: Round

    // The team this result is associated with
    @Parent(key: RoundResult.FieldKeys.teamID)
    var team: Team
    
    // The points earned by the team in this round
    @Field(key: RoundResult.FieldKeys.teamPoints)
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