import Fluent
import Vapor

/// Model representing a round in the database, which is part of a game
final class Round: Model, Content, @unchecked Sendable {
/// Enumeration representing the current phase of the round
 enum CurrentPhase: String, Codable {
        case uploading
        case viewingPhotos
        case guessing
        case calculatingResults
        case roundOver
    }

    static let schema = "rounds"
    // Unique identifier for each round 
    @ID(key: .id)
    var id: UUID?

    // The current phase of the round
    @Enum(key: "current_phase")
    var currentPhase: CurrentPhase

    // The game that this round belongs to
    @Parent(key: "game_id")
    var game: Game

    // The round number within the game
    @Field(key: "round_number")
    var roundNumber: Int

    // Deadline for the round, which can be used to determine when the round should end
    @Field(key: "deadline") 
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