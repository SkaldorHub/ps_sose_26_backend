import Vapor

// PLACEHOLDER: Bearer token wird als rohe UUID behandelt.
// AuthController-Branch ersetzt diese Middleware durch echte JWT-Validierung.
struct AuthMiddleware: AsyncMiddleware {

    @TaskLocal static var currentUserID: UUID?

    func respond(to request: Request, chainingTo responder: any AsyncResponder) async throws -> Response {
        let userID = request.headers.bearerAuthorization.flatMap { UUID(uuidString: $0.token) }
        return try await AuthMiddleware.$currentUserID.withValue(userID) {
            try await responder.respond(to: request)
        }
    }
}
