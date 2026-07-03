import OpenAPIRuntime
import Vapor
import Fluent

extension APIHandler {

    private var db: any Database { app.db }

    private func currentUserID() throws -> UUID {
        guard let id = AuthMiddleware.currentUserID else { throw Abort(.unauthorized) }
        return id
    }

    private func myTeamID(gameId: UUID, userID: UUID) async throws -> UUID? {
        try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameId)
            .filter(\.$user.$id == userID)
            .first()?.$team.id
    }

    private func currentRound(gameId: UUID) async throws -> Round? {
        try await Round.query(on: db)
            .filter(\.$game.$id == gameId)
            .sort(\.$roundNumber, .ascending)
            .all()
            .first { $0.currentPhase != .calculateResults }
    }

    func getTeamPhoto(_ input: Operations.getTeamPhoto.Input) async throws -> Operations.getTeamPhoto.Output {
        guard let gameId = UUID(uuidString: input.path.gameId),
              let teamId = UUID(uuidString: input.path.teamId) else { return .notFound(.init()) }
        let userID = try currentUserID()

        guard let myTeam = try await myTeamID(gameId: gameId, userID: userID), myTeam != teamId else {
            return .forbidden(.init())
        }

        guard let round = try await currentRound(gameId: gameId), round.currentPhase == .guess else {
            return .forbidden(.init())
        }

        guard let photographer = try await RoundPhotographer.query(on: db)
            .filter(\.$round.$id == round.requireID())
            .filter(\.$team.$id == teamId)
            .first() else { return .notFound(.init()) }

        guard let photo = try await Photo.query(on: db)
            .filter(\.$round.$id == round.requireID())
            .filter(\.$photographer.$id == photographer.$user.id)
            .first() else { return .notFound(.init()) }

        let bytes = try await app.photoStorage.download(key: photo.photoURL)
        return .ok(.init(body: .image__ast_(.init([UInt8](bytes.readableBytesView)))))
    }

    func submitGuess(_ input: Operations.submitGuess.Input) async throws -> Operations.submitGuess.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else { return .notFound(.init()) }
        let userID = try currentUserID()
        guard case let .json(body) = input.body else { throw Abort(.badRequest) }

        guard let round = try await currentRound(gameId: gameId), round.currentPhase == .guess else {
            return .forbidden(.init())
        }
        let roundID = try round.requireID()

        guard try await Guess.query(on: db)
            .filter(\.$round.$id == roundID)
            .filter(\.$user.$id == userID)
            .first() == nil else { return .conflict(.init()) }

        guard let myTeam = try await myTeamID(gameId: gameId, userID: userID) else { return .forbidden(.init()) }

        guard let opponentPhotographer = try await RoundPhotographer.query(on: db)
            .filter(\.$round.$id == roundID)
            .filter(\.$team.$id != myTeam)
            .first(),
            let opponentPhoto = try await Photo.query(on: db)
                .filter(\.$round.$id == roundID)
                .filter(\.$photographer.$id == opponentPhotographer.$user.id)
                .first()
        else { return .notFound(.init()) }

        let distance = Scoring.distanceMeters(lat1: body.lat, lng1: body.lng, lat2: opponentPhoto.latitude, lng2: opponentPhoto.longitude)
        let points = Scoring.points(distanceMeters: distance)

        let guess = Guess(
            userId: userID, roundId: roundID,
            latitude: body.lat, longitude: body.lng,
            distance: distance, points: points,
            viewingDeadline: round.deadline ?? Date(),
            guessDeadline: round.deadline ?? Date()
        )
        try await guess.save(on: db)

        return .created(.init(body: .json(.init(
            id: try guess.requireID().uuidString,
            playerId: userID.uuidString,
            lat: guess.latitude, lng: guess.longitude,
            distanceMeters: distance,
            viewingDeadline: guess.viewingDeadline,
            guessDeadline: guess.guessDeadline
        ))))
    }

    func getGuesses(_ input: Operations.getGuesses.Input) async throws -> Operations.getGuesses.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else { return .notFound(.init()) }
        _ = try currentUserID()

        guard let round = try await currentRound(gameId: gameId) else { return .notFound(.init()) }
        let guesses = try await Guess.query(on: db).filter(\.$round.$id == round.requireID()).all()

        return .ok(.init(body: .json(try guesses.map {
            .init(id: try $0.requireID().uuidString, playerId: $0.$user.id.uuidString,
                  lat: $0.latitude, lng: $0.longitude, distanceMeters: $0.distance,
                  viewingDeadline: $0.viewingDeadline, guessDeadline: $0.guessDeadline)
        })))
    }
}
