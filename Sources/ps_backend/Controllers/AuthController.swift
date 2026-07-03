import OpenAPIRuntime
import Vapor
import Fluent
import JWT

extension APIHandler {

    private func findUser(username: String) async throws -> User? {
        try await User.query(on: app.db).filter(\.$username == username).first()
    }

    private func issueToken(for user: User) async throws -> String {
        let payload = UserPayload(
            userId: try user.requireID(),
            userName: user.username,
            exp: .init(value: Date().addingTimeInterval(60 * 60 * 24 * 7))
        )
        return try await app.jwt.keys.sign(payload)
    }

    func register(_ input: Operations.register.Input) async throws -> Operations.register.Output {
        guard case let .json(body) = input.body else { throw Abort(.badRequest) }
        guard body.username.count >= 3, body.password.count >= 6 else {
            return .badRequest(.init())
        }
        guard try await findUser(username: body.username) == nil else {
            return .badRequest(.init())
        }

        let user = User(username: body.username, passwordHash: try Bcrypt.hash(body.password))
        try await user.save(on: app.db)

        return .created(.init(body: .json(.init(
            token: try await issueToken(for: user),
            userId: try user.requireID().uuidString,
            username: user.username
        ))))
    }

    func login(_ input: Operations.login.Input) async throws -> Operations.login.Output {
        guard case let .json(body) = input.body else { throw Abort(.badRequest) }
        guard let user = try await findUser(username: body.username) else {
            return .unauthorized(.init())
        }
        guard try Bcrypt.verify(body.password, created: user.passwordHash) else {
            return .unauthorized(.init())
        }

        return .ok(.init(body: .json(.init(
            token: try await issueToken(for: user),
            userId: try user.requireID().uuidString,
            username: user.username
        ))))
    }

    func logout(_ input: Operations.logout.Input) async throws -> Operations.logout.Output {
        guard AuthMiddleware.currentUserID != nil else { return .unauthorized(.init()) }
        return .noContent
    }
}
