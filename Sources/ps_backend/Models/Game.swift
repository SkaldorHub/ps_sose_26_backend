import Fluent
import Vapor

/// This model represents a game in the database, including the host, state, and associated rounds and participations.
final class Game: Model, Content, @unchecked Sendable {

    // A collection of field keys for the Game model
    struct FieldKeys {
        static var hostID: FieldKey { "host_id" }
        static var state: FieldKey { "state" }
        static var startedAt: FieldKey { "started_at" }
        static var finishedAt: FieldKey { "finished_at" }
        static var code: FieldKey { "code" }
        static var totalRounds: FieldKey { "total_rounds" }
        static var maxPlayers: FieldKey { "max_players" }
        static var roundDurationHours: FieldKey { "round_duration_hours" }
        static var photoViewSeconds: FieldKey { "photo_view_seconds" }
        static var createdAt: FieldKey { "created_at" }
    }

    /// Enumeration representing the state of the game
    enum State: String, Codable {
        // The game is in the lobby, waiting for players to join
        case lobby
        // The game is currently running
        case running
        // The game has finished
        case gameOver
    }

    static let schema = "games"

    // Unique identifier for the game
    @ID(key: .id)
    var id: UUID?

    // The user who is hosting the game
    @Parent(key: FieldKeys.hostID)
    var host: User

    // The current state of the game
    @Enum(key: FieldKeys.state)
    var state: Game.State

    // The date and time the game started
    @OptionalField(key: FieldKeys.startedAt)
    var startedAt: Date?

    // The date and time the game finished
    @OptionalField(key: FieldKeys.finishedAt)
    var finishedAt: Date?

    // Short join code for the game
    @Field(key: FieldKeys.code)
    var code: String

    // Total number of rounds in the game
    @Field(key: FieldKeys.totalRounds)
    var totalRounds: Int

    // Maximum number of players allowed
    @Field(key: FieldKeys.maxPlayers)
    var maxPlayers: Int

    // Duration of each round in hours
    @Field(key: FieldKeys.roundDurationHours)
    var roundDurationHours: Int

    // Seconds players have to view the opponent's photo
    @Field(key: FieldKeys.photoViewSeconds)
    var photoViewSeconds: Int

    // Timestamp of when the game was created
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    // The teams participating in this game
    @Children(for: \.$game)
    var participates: [Participate]

    // The rounds associated with this game
    @Children(for: \.$game)
    var rounds: [Round]

    // The team members associated with this game
    @Children(for: \.$game)
    var teamMembers: [TeamMember]

    // Initializer for the Game model
    init() {}
    
    // Initializer for the Game model with parameters for id, state, hostID, and config fields
    init(id: UUID? = nil, state: Game.State, hostID: UUID,
         code: String, totalRounds: Int, maxPlayers: Int,
         roundDurationHours: Int, photoViewSeconds: Int) {
        self.id = id
        self.state = state
        self.$host.id = hostID
        self.code = code
        self.totalRounds = totalRounds
        self.maxPlayers = maxPlayers
        self.roundDurationHours = roundDurationHours
        self.photoViewSeconds = photoViewSeconds
    }
}
