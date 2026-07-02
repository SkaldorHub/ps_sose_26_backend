import Fluent
import Vapor

final class Game: Model, Content, @unchecked Sendable {

    struct FieldKeys {
        static var hostID: FieldKey { "host_id" }
        static var state: FieldKey { "state" }
        static var startedAt: FieldKey { "started_at" }
        static var finishedAt: FieldKey { "finished_at" }
        static var code: FieldKey { "code" }
        static var name: FieldKey { "name" }
        static var totalRounds: FieldKey { "total_rounds" }
        static var maxPlayers: FieldKey { "max_players" }
        static var roundDurationHours: FieldKey { "round_duration_hours" }
        static var uploadPhaseHours: FieldKey { "upload_phase_hours" }
        static var guessingPhaseHours: FieldKey { "guessing_phase_hours" }
        static var photoViewSeconds: FieldKey { "photo_view_seconds" }
        static var setMarkerSeconds: FieldKey { "set_marker_seconds" }
        static var createdAt: FieldKey { "created_at" }
    }

    enum State: String, Codable {
        case lobby
        case running
        case gameOver
    }

    static let schema = "games"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: FieldKeys.hostID)
    var host: User

    @Enum(key: FieldKeys.state)
    var state: Game.State

    @OptionalField(key: FieldKeys.startedAt)
    var startedAt: Date?

    @OptionalField(key: FieldKeys.finishedAt)
    var finishedAt: Date?

    @Field(key: FieldKeys.code)
    var code: String

    @Field(key: FieldKeys.name)
    var name: String

    @Field(key: FieldKeys.totalRounds)
    var totalRounds: Int

    @Field(key: FieldKeys.maxPlayers)
    var maxPlayers: Int

    @Field(key: FieldKeys.roundDurationHours)
    var roundDurationHours: Int

    @Field(key: FieldKeys.uploadPhaseHours)
    var uploadPhaseHours: Int

    @Field(key: FieldKeys.guessingPhaseHours)
    var guessingPhaseHours: Int

    @Field(key: FieldKeys.photoViewSeconds)
    var photoViewSeconds: Int

    @Field(key: FieldKeys.setMarkerSeconds)
    var setMarkerSeconds: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$game)
    var participates: [Participate]

    @Children(for: \.$game)
    var rounds: [Round]

    @Children(for: \.$game)
    var teamMembers: [TeamMember]

    init() {}

    init(id: UUID? = nil, state: Game.State, hostID: UUID,
         code: String, name: String, totalRounds: Int, maxPlayers: Int,
         roundDurationHours: Int, uploadPhaseHours: Int, guessingPhaseHours: Int,
         photoViewSeconds: Int, setMarkerSeconds: Int) {
        self.id = id
        self.state = state
        self.$host.id = hostID
        self.code = code
        self.name = name
        self.totalRounds = totalRounds
        self.maxPlayers = maxPlayers
        self.roundDurationHours = roundDurationHours
        self.uploadPhaseHours = uploadPhaseHours
        self.guessingPhaseHours = guessingPhaseHours
        self.photoViewSeconds = photoViewSeconds
        self.setMarkerSeconds = setMarkerSeconds
    }
}
