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
    
    // Initializer for the Game model with parameters for id, state, and hostID
    init(id: UUID? = nil, state: Game.State, hostID: UUID) {
        self.id = id
        self.state = state
        self.$host.id = hostID
    }
}