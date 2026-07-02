import Fluent
import Vapor

final class TeamMember: Model, Content, @unchecked Sendable {

    struct FieldKeys {
        static var teamID: FieldKey { "team_id" }
        static var userID: FieldKey { "user_id" }
        static var gameID: FieldKey { "game_id" }
        static var joinedAt: FieldKey { "joined_at" }
    }

    static let schema = "team_members"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: FieldKeys.teamID)
    var team: Team

    @Parent(key: FieldKeys.userID)
    var user: User

    @Parent(key: FieldKeys.gameID)
    var game: Game

    @Timestamp(key: FieldKeys.joinedAt, on: .create)
    var joinedAt: Date?

    init() {}

    init(id: UUID? = nil, teamID: UUID, userID: UUID, gameID: UUID) {
        self.id = id
        self.$team.id = teamID
        self.$user.id = userID
        self.$game.id = gameID
    }
}
