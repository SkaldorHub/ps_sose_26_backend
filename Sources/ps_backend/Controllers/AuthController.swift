import OpenAPIRuntime
import JWT

extension APIHandler {

    //why all _ input : etc
    func register(_ input: Operations.register.Input) async throws -> Operations.register.Output {
        .undocumented(statusCode: 501, .init())
    }

    // Content Structs for return needed? mby Operations.login.Output??
    func login(_ input: Operations.login.Input) async throws -> Operations.login.Output {
        .undocumented(statusCode: 501, .init())
    }

    func logout(_ input: Operations.logout.Input) async throws -> Operations.logout.Output {
        .undocumented(statusCode: 501, .init())
    }
}

struct AuthPayload: JWTPayload {
    // Maps the longer Swift property names to the
    // shortened keys used in the JWT payload.
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case username = "usr"
    }

    var subject: SubjectClaim
    
    var expiration: ExpirationClaim

    var username: String
    
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}
