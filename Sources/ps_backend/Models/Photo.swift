import Fluent   
import Vapor

/// This model represents a photo uploaded by a team during the uploading phase of a round, including the URL of the photo and its association with a specific round and team.
final class Photo: Model, Content, @unchecked Sendable {
    static let schema = "photos"
    // Unique identifier for each photo
    @ID(key: .id)
    var id: UUID?

    // The round associated with the photo
    @Parent(key: "round_id")
    var round: Round

    // The team that uploaded the photo
    @Parent(key: "photographer_id")
    var photographer: User

    // latitude of the location where the photo was taken
    @Field(key: "latitude")
    var latitude: Double

    // longitude of the location where the photo was taken
    @Field(key: "longitude")
    var longitude: Double

    // optional hint for the photo
    @OptionalField(key: "hint")
    var hint: String?

    // URL of the uploaded photo
    @Field(key: "photo_url")
    var photoURL: String

    // Initializers for the Photo model
    init() { }

    // Initializer for the Photo model with parameters for id, roundId, photographerId, latitude, longitude, hint, and photoURL
    init(id: UUID? = nil, roundId: UUID, photographerId: UUID, latitude: Double, longitude: Double, hint: String? = nil, photoURL: String) {
        self.id = id
        self.$round.id = roundId
        self.$photographer.id = photographerId
        self.latitude = latitude
        self.longitude = longitude
        self.hint = hint
        self.photoURL = photoURL
    }
}