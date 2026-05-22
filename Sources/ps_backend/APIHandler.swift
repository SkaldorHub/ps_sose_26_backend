import OpenAPIRuntime

struct APIHandler: APIProtocol {

    // MARK: - Auth

    func register(_ input: Operations.register.Input) async throws -> Operations.register.Output {
        .undocumented(statusCode: 501, .init())
    }

    func login(_ input: Operations.login.Input) async throws -> Operations.login.Output {
        .undocumented(statusCode: 501, .init())
    }

    func logout(_ input: Operations.logout.Input) async throws -> Operations.logout.Output {
        .undocumented(statusCode: 501, .init())
    }

    // MARK: - Lobby

    func createGame(_ input: Operations.createGame.Input) async throws -> Operations.createGame.Output {
        .undocumented(statusCode: 501, .init())
    }

    func joinGame(_ input: Operations.joinGame.Input) async throws -> Operations.joinGame.Output {
        .undocumented(statusCode: 501, .init())
    }

    func getGame(_ input: Operations.getGame.Input) async throws -> Operations.getGame.Output {
        .undocumented(statusCode: 501, .init())
    }

    func startGame(_ input: Operations.startGame.Input) async throws -> Operations.startGame.Output {
        .undocumented(statusCode: 501, .init())
    }

    func leaveGame(_ input: Operations.leaveGame.Input) async throws -> Operations.leaveGame.Output {
        .undocumented(statusCode: 501, .init())
    }

    func listPlayers(_ input: Operations.listPlayers.Input) async throws -> Operations.listPlayers.Output {
        .undocumented(statusCode: 501, .init())
    }

    func kickPlayer(_ input: Operations.kickPlayer.Input) async throws -> Operations.kickPlayer.Output {
        .undocumented(statusCode: 501, .init())
    }

    func listTeams(_ input: Operations.listTeams.Input) async throws -> Operations.listTeams.Output {
        .undocumented(statusCode: 501, .init())
    }

    // MARK: - Round

    func getCurrentRound(_ input: Operations.getCurrentRound.Input) async throws -> Operations.getCurrentRound.Output {
        .undocumented(statusCode: 501, .init())
    }

    func uploadPhoto(_ input: Operations.uploadPhoto.Input) async throws -> Operations.uploadPhoto.Output {
        .undocumented(statusCode: 501, .init())
    }

    func replacePhoto(_ input: Operations.replacePhoto.Input) async throws -> Operations.replacePhoto.Output {
        .undocumented(statusCode: 501, .init())
    }

    func deletePhoto(_ input: Operations.deletePhoto.Input) async throws -> Operations.deletePhoto.Output {
        .undocumented(statusCode: 501, .init())
    }

    func getUploadStatus(_ input: Operations.getUploadStatus.Input) async throws -> Operations.getUploadStatus.Output {
        .undocumented(statusCode: 501, .init())
    }

    // MARK: - Guess

    func getTeamPhoto(_ input: Operations.getTeamPhoto.Input) async throws -> Operations.getTeamPhoto.Output {
        .undocumented(statusCode: 501, .init())
    }

    func submitGuess(_ input: Operations.submitGuess.Input) async throws -> Operations.submitGuess.Output {
        .undocumented(statusCode: 501, .init())
    }

    func getGuesses(_ input: Operations.getGuesses.Input) async throws -> Operations.getGuesses.Output {
        .undocumented(statusCode: 501, .init())
    }

    // MARK: - Results

    func getCurrentResult(_ input: Operations.getCurrentResult.Input) async throws -> Operations.getCurrentResult.Output {
        .undocumented(statusCode: 501, .init())
    }

    func getLeaderboard(_ input: Operations.getLeaderboard.Input) async throws -> Operations.getLeaderboard.Output {
        .undocumented(statusCode: 501, .init())
    }

    func getGameResult(_ input: Operations.getGameResult.Input) async throws -> Operations.getGameResult.Output {
        .undocumented(statusCode: 501, .init())
    }
}
