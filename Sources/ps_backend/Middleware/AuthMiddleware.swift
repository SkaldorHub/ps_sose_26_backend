import Vapor
import JWT

struct UserPayload: JWTPayload {
    enum CodingKeys: String, CodingKey {
        case userId
        case userName
        case exp
    }

    var userId: UUID
    var userName: String
    var exp: ExpirationClaim

    func verify(using algorithm: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}

struct AuthMiddleware: AsyncMiddleware {

    @TaskLocal static var currentUserID: UUID?

    func respond(to request: Request, chainingTo responder: any AsyncResponder) async throws -> Response {
        let userID = try? await request.jwt.verify(as: UserPayload.self).userId
        return try await AuthMiddleware.$currentUserID.withValue(userID) {
            try await responder.respond(to: request)
        }
    }
}
