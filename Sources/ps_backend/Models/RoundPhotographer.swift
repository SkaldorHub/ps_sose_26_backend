import Fluent
import Vapor

final class RoundPhotographer: Model, Content, @unchecked Sendable {

    struct FieldKeys {
        static var roundID: FieldKey { "round_id" }
        static var teamID: FieldKey { "team_id" }
        static var userID: FieldKey { "user_id" }
    }

    static let schema = "round_photographers"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: FieldKeys.roundID)
    var round: Round

    @Parent(key: FieldKeys.teamID)
    var team: Team

    @Parent(key: FieldKeys.userID)
    var user: User

    init() {}

    init(roundID: UUID, teamID: UUID, userID: UUID) {
        self.$round.id = roundID
        self.$team.id = teamID
        self.$user.id = userID
    }
}
