import Fluent
import Vapor

final class Team: Model, Content, @unchecked Sendable {

    struct FieldKeys {
        static var name: FieldKey { "name" }
    }

    static let schema = "teams"

    @ID(key: .id)
    var id: UUID?

    @Field(key: FieldKeys.name)
    var name: String

    @Children(for: \.$team)
    var participates: [Participate]

    @Children(for: \.$team)
    var roundResults: [RoundResult]

    @Children(for: \.$team)
    var teamMembers: [TeamMember]

    init() {}

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
