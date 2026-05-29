import Fluent   
import Vapor

// Model representing a team in the database
final class Team: Model, Content {
    static let schema = "team"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "user_id")
    var user: User

    @Children(for: \.$team)
    var participates: [Participates]

    init() {}

    init(id: UUID? = nil, name: String, userID: UUID) {
        self.id = id
        self.name = name
        self.$user.id = userID
    }
}