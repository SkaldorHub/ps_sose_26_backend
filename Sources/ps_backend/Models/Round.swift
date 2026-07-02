import Fluent
import Vapor

final class Round: Model, Content, @unchecked Sendable {

    struct FieldKeys {
        static var gameID: FieldKey { "game_id" }
        static var roundNumber: FieldKey { "round_number" }
        static var currentPhase: FieldKey { "current_phase" }
        static var deadline: FieldKey { "deadline" }
    }

    enum CurrentPhase: String, Codable {
        case upload
        case guess
        case calculateResults
    }

    static let schema = "rounds"

    @ID(key: .id)
    var id: UUID?

    @Enum(key: FieldKeys.currentPhase)
    var currentPhase: CurrentPhase

    @Parent(key: FieldKeys.gameID)
    var game: Game

    @Field(key: FieldKeys.roundNumber)
    var roundNumber: Int

    @Field(key: FieldKeys.deadline)
    var deadline: Date?

    @Children(for: \.$round)
    var photographers: [RoundPhotographer]

    @Children(for: \.$round)
    var roundResults: [RoundResult]

    @Children(for: \.$round)
    var guesses: [Guess]

    @Children(for: \.$round)
    var photos: [Photo]

    init() {}

    init(id: UUID? = nil, currentPhase: CurrentPhase, gameID: UUID, roundNumber: Int, deadline: Date? = nil) {
        self.id = id
        self.currentPhase = currentPhase
        self.$game.id = gameID
        self.roundNumber = roundNumber
        self.deadline = deadline
    }
}