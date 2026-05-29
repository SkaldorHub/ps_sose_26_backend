import OpenAPIRuntime
import JWT

extension APIHandler {

    //why all _ input : etc
    func register(_ input: Operations.register.Input) async throws -> Operations.register.Output {
        .undocumented(statusCode: 501, .init())
    }

    // Content Structs for return needed? mby Operations.login.Output??
    func login(req: Request) async throws -> Operations.login.Output {
        .undocumented(statusCode: 501, .init())
    }

    func logout(_ input: Operations.logout.Input) async throws -> Operations.logout.Output {
        .undocumented(statusCode: 501, .init())
    }
}

/*

Payload needed -> in Model?

struct AuthPayload: JWTPayload {

    //What information needs to be transmitted?

}

*/
