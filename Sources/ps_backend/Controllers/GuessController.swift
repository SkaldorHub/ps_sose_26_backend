import OpenAPIRuntime
import Vapor
import Fluent

extension APIHandler {

    private var db: any Database { app.db }

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

    /// Löst eine Runde explizit über ihre ID auf (statt implizit per Phase "aktuelle Runde" zu
    /// erraten) - verhindert eine Race zwischen dem 5s-Phasen-Scheduler und Requests, die kurz
    /// nach einem Rundenwechsel für die vorherige Runde ankommen (siehe submitGuess/getGuesses).
    private func round(id: UUID, gameId: UUID) async throws -> Round? {
        try await Round.query(on: db)
            .filter(\.$id == id)
            .filter(\.$game.$id == gameId)
            .first()
    }

    func getTeamPhoto(_ input: Operations.getTeamPhoto.Input) async throws -> Operations.getTeamPhoto.Output {
        guard let gameId = UUID(uuidString: input.path.gameId),
              let teamId = UUID(uuidString: input.path.teamId) else { return .notFound(.init()) }
        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }

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
        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }
        guard case let .json(body) = input.body else { return .badRequest(.init()) }
        guard let bodyRoundID = UUID(uuidString: body.roundId) else { return .notFound(.init()) }
        guard (-90...90).contains(body.lat), (-180...180).contains(body.lng) else { return .forbidden(.init()) }

        guard let round = try await round(id: bodyRoundID, gameId: gameId), round.currentPhase == .guess else {
            return .forbidden(.init())
        }
        let roundID = try round.requireID()

        guard try await Guess.query(on: db)
            .filter(\.$round.$id == roundID)
            .filter(\.$user.$id == userID)
            .first() == nil else { return .conflict(.init()) }

        // Bewusst .notFound statt .forbidden: der Client behandelt .forbidden hier als "Guess-
        // Phase vorbei, aber kein echter Fehler" (siehe PlaceMarkerViewModel.submitGuess) - das
        // gilt nur für den Phase-Check oben, nicht für "User ist gar kein Mitglied dieses
        // Spiels", was ein echter (wenn auch unerwarteter) Fehlerfall ist.
        guard let myTeam = try await myTeamID(gameId: gameId, userID: userID) else { return .notFound(.init()) }

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
        do {
            try await guess.save(on: db)
        } catch let error as any DatabaseError where error.isConstraintFailure {
            // Zwei parallele submitGuess-Requests desselben Users können den obigen
            // Application-Level-Check beide passieren (TOCTOU) - der bereits vorhandene
            // DB-Unique-Constraint auf (userID, roundID) ist die eigentliche Absicherung.
            return .conflict(.init())
        }

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
        guard let gameId = UUID(uuidString: input.path.gameId),
              let roundId = UUID(uuidString: input.query.roundId) else { return .notFound(.init()) }
        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }
        // Ohne diesen Check könnte jeder registrierte Account Guesses (Standorte, Distanzen)
        // eines beliebigen fremden Spiels abrufen, sofern gameId/roundId bekannt sind.
        guard try await myTeamID(gameId: gameId, userID: userID) != nil else { return .forbidden(.init()) }

        guard let round = try await round(id: roundId, gameId: gameId) else { return .notFound(.init()) }
        let guesses = try await Guess.query(on: db).filter(\.$round.$id == round.requireID()).all()

        return .ok(.init(body: .json(try guesses.map {
            .init(id: try $0.requireID().uuidString, playerId: $0.$user.id.uuidString,
                  lat: $0.latitude, lng: $0.longitude, distanceMeters: $0.distance,
                  viewingDeadline: $0.viewingDeadline, guessDeadline: $0.guessDeadline)
        })))
    }
}
