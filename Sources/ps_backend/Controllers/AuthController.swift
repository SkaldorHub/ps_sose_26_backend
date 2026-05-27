import OpenAPIRuntime

extension APIHandler {

    func register(_ input: Operations.register.Input) async throws -> Operations.register.Output {
        .undocumented(statusCode: 501, .init())
    }

    func login(_ input: Operations.login.Input) async throws -> Operations.login.Output {
        .undocumented(statusCode: 501, .init())
    }

    func logout(_ input: Operations.logout.Input) async throws -> Operations.logout.Output {
        .undocumented(statusCode: 501, .init())
    }
}
