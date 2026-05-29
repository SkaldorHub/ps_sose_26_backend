import Fluent
import Vapor

// Model representing a game in the database
final class Game: Model, Content {
    static let schema = "game"

    @ID(key: .id)
    var id: UUID?

    @Enum(key: "state")
    var state: GameState

    @Parent(key: "host_id")
    var host: User

    @Timestamp(key: "started_at", on: .create)
    var startedAt: Date?

    @OptionalField(key: "finished_at")
    var finishedAt: Date?

    @Children(for: \.$game)
    var participates: [Participates]
    
    init() {}

    init(id: UUID? = nil, state: GameState, hostID: UUID) {
        self.id = id
        self.state = state
        self.$host.id = hostID 
    }
}