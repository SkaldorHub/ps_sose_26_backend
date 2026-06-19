import Fluent
import Vapor

/// Model representing a round in the database, which is part of a game
final class Round: Model, Content, @unchecked Sendable {

    // A collection of field keys for the Round model
    struct FieldKeys {
        static var gameID: FieldKey { "game_id" }
        static var roundNumber: FieldKey { "round_number" }
        static var currentPhase: FieldKey { "current_phase" }
        static var deadline: FieldKey { "deadline" }
    }

    /// Enumeration representing the current phase of the round
    enum CurrentPhase: String, Codable {
        case upload
        case guess
        case calculateResults
    }

    static let schema = "rounds"

    // Unique identifier for each round 
    @ID(key: .id)
    var id: UUID?

    // The current phase of the round
    @Enum(key: Round.FieldKeys.currentPhase)
    var currentPhase: CurrentPhase

    // The game that this round belongs to
    @Parent(key: Round.FieldKeys.gameID)
    var game: Game

    // The round number within the game
    @Field(key: Round.FieldKeys.roundNumber)
    var roundNumber: Int

    // Deadline for the round, which can be used to determine when the round should end
    @Field(key: Round.FieldKeys.deadline)
    var deadline: Date?

    // The round results associated with this round
    @Children(for: \.$round)
    var roundResults: [RoundResult]

    // The guesses made during this round
    @Children(for: \.$round)
    var guesses: [Guess]

   // The photos taken during this round
    @Children(for: \.$round)
    var photos: [Photo]

    // Initializers for the Round model
    init() {}
    
    // Initializer for the Round model with parameters for id, currentPhase, gameID, roundNumber, and deadline
    init(id: UUID? = nil, currentPhase: CurrentPhase, gameID: UUID, roundNumber: Int, deadline: Date? = nil) {
        self.id = id
        self.currentPhase = currentPhase
        self.$game.id = gameID
        self.roundNumber = roundNumber
        self.deadline = deadline
    }
}