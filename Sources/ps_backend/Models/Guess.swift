import Fluent   
import Vapor

/// This model represents a guess made by a user for the location of a photo in a specific round, including the latitude and longitude of the guessed location and the distance from the actual location of the photo.
final class Guess: Model, Content, @unchecked Sendable {

    // A collection of field keys for the Guess model
    struct FieldKeys {
        static var userID: FieldKey { "user_id" }
        static var roundID: FieldKey { "round_id" }
        static var latitude: FieldKey { "latitude" }
        static var longitude: FieldKey { "longitude" }
        static var distance: FieldKey { "distance" }
        static var viewingDeadline: FieldKey { "viewing_deadline" }
        static var guessDeadline: FieldKey { "guess_deadline" }
    }
    
    static let schema = "guesses"

    // Unique identifier for each guess
    @ID(key: .id)
    var id: UUID?

    // The guess made by the user for the location of the photo
    @Parent(key: Guess.FieldKeys.userID)
    var user: User

    // The round associated with the guess
    @Parent(key: Guess.FieldKeys.roundID)
    var round: Round

    // latitude of the guessed location
    @Field(key: Guess.FieldKeys.latitude)
    var latitude: Double

    // longitude of the guessed location
    @Field(key: Guess.FieldKeys.longitude)
    var longitude: Double

    // distance from the actual location of the photo to the guessed location
    @OptionalField(key: Guess.FieldKeys.distance)
    var distance: Double?

    // deadline for viewing the guess
    @Field(key: Guess.FieldKeys.viewingDeadline)
    var viewingDeadline: Date

    // deadline for making the guess
    @Field(key: Guess.FieldKeys.guessDeadline)
    var guessDeadline: Date

    // Initializer for the Guess model
    init() { }
    
    // Initializer for the Guess model with parameters for id, userId, roundId, latitude, longitude, distance, and viewingDeadline
    init(id: UUID? = nil, userId: UUID, roundId: UUID, latitude: Double, longitude: Double, distance: Double? = nil, viewingDeadline: Date, guessDeadline: Date) {
        self.id = id
        self.$user.id = userId
        self.$round.id = roundId
        self.latitude = latitude
        self.longitude = longitude
        self.distance = distance
        self.viewingDeadline = viewingDeadline
        self.guessDeadline = guessDeadline
    }
}