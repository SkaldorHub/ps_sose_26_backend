import OpenAPIRuntime
import Vapor
import Fluent

extension APIHandler {

    private var db: any Database { app.db }

    private func currentRound(gameId: UUID) async throws -> Round? {
        try await Round.query(on: db)
            .filter(\.$game.$id == gameId)
            .sort(\.$roundNumber, .ascending)
            .all()
            .first { $0.currentPhase != .calculateResults }
    }

    /// Löst eine Runde explizit über ihre ID auf (statt implizit per Phase "aktuelle Runde" zu
    /// erraten) - verhindert eine Race zwischen dem 5s-Phasen-Scheduler und Upload-Requests, die
    /// kurz nach einem Rundenwechsel für die vorherige Runde ankommen (siehe GuessController).
    private func round(id: UUID, gameId: UUID) async throws -> Round? {
        try await Round.query(on: db)
            .filter(\.$id == id)
            .filter(\.$game.$id == gameId)
            .first()
    }

    /// Ohne diesen Check kann jeder registrierte Account Rundenzustand/Upload-Status eines
    /// beliebigen fremden Spiels abrufen, sofern die gameId bekannt ist. Gibt bewusst Bool statt
    /// throw Abort(...) zurück: ein direkt geworfener Abort-Fehler wird von der OpenAPI-Server-
    /// Transportschicht innerhalb eines Operation-Handlers nicht auf den richtigen HTTP-Status
    /// gemappt, sondern generisch als 500 "Something went wrong" beantwortet - nur typisierte
    /// Operation-Outputs (.forbidden(.init())) liefern den korrekten Statuscode.
    private func isMember(gameId: UUID, userID: UUID) async throws -> Bool {
        try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameId)
            .filter(\.$user.$id == userID)
            .first() != nil
    }

    func getCurrentRound(_ input: Operations.getCurrentRound.Input) async throws -> Operations.getCurrentRound.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else { return .notFound(.init()) }
        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }
        guard try await isMember(gameId: gameId, userID: userID) else { return .forbidden(.init()) }

        guard let game = try await Game.find(gameId, on: db) else { return .notFound(.init()) }
        guard game.state == .running else { return .conflict(.init()) }

        guard let round = try await currentRound(gameId: gameId) else { return .notFound(.init()) }
        // Kein Force-Unwrap: Model-Enum (Round.CurrentPhase) und OpenAPI-Schema-Enum
        // (RoundPhase) müssen synchron gehalten werden - bei künftiger Divergenz eines Falls
        // soll das ein sprechender 500er statt eines Server-Crashs sein.
        guard let phase = Components.Schemas.RoundPhase(rawValue: round.currentPhase.rawValue) else {
            throw Abort(.internalServerError, reason: "Unbekannte Rundenphase: \(round.currentPhase.rawValue)")
        }
        let photographers = try await RoundPhotographer.query(on: db)
            .filter(\.$round.$id == round.requireID())
            .all()

        return .ok(.init(body: .json(.init(
            id: try round.requireID().uuidString,
            roundNumber: round.roundNumber,
            phase: phase,
            deadline: round.deadline,
            photographers: photographers.map {
                .init(teamId: $0.$team.id.uuidString, userId: $0.$user.id.uuidString)
            }
        ))))
    }

    func uploadPhoto(_ input: Operations.uploadPhoto.Input) async throws -> Operations.uploadPhoto.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else { return .notFound(.init()) }
        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }

        guard case let .multipartForm(form) = input.body else { return .badRequest(.init()) }
        var photoBytes: [UInt8] = []
        var roundId: UUID?
        var lat: Double?
        var lng: Double?
        var hint: String?
        for try await part in form {
            switch part {
            case .roundId(let part):
                roundId = try await UUID(uuidString: String(collecting: part.payload.body, upTo: 64))
            case .photo(let part):
                photoBytes = try await [UInt8](collecting: part.payload.body, upTo: 20 * 1024 * 1024)
            case .lat(let part):
                lat = try await Double(String(collecting: part.payload.body, upTo: 64))
            case .lng(let part):
                lng = try await Double(String(collecting: part.payload.body, upTo: 64))
            case .hint(let part):
                hint = try await String(collecting: part.payload.body, upTo: 512)
            case .undocumented:
                continue
            }
        }
        guard let roundId, let lat, let lng, !photoBytes.isEmpty else { return .forbidden(.init()) }
        guard (-90...90).contains(lat), (-180...180).contains(lng) else { return .forbidden(.init()) }

        guard let round = try await round(id: roundId, gameId: gameId) else { return .notFound(.init()) }
        guard round.currentPhase == .upload else { return .forbidden(.init()) }
        if let deadline = round.deadline, deadline < Date() { return .gone(.init()) }

        let roundID = try round.requireID()
        guard try await RoundPhotographer.query(on: db)
            .filter(\.$round.$id == roundID)
            .filter(\.$user.$id == userID)
            .first() != nil else { return .forbidden(.init()) }

        guard try await Photo.query(on: db)
            .filter(\.$round.$id == roundID)
            .filter(\.$photographer.$id == userID)
            .first() == nil else { return .conflict(.init()) }

        let key = "\(roundID)/\(userID).jpg"
        let photoURL = try await app.photoStorage.upload(data: photoBytes, key: key, contentType: "image/jpeg")

        let photo = Photo(roundId: roundID, photographerId: userID, latitude: lat, longitude: lng, hint: hint, photoURL: photoURL)
        do {
            try await photo.save(on: db)
        } catch let error as any DatabaseError where error.isConstraintFailure {
            // Zwei parallele Upload-Requests desselben Fotografen können den obigen
            // Application-Level-Check beide passieren (TOCTOU) - der DB-Unique-Constraint auf
            // (roundID, photographerID) ist die eigentliche Absicherung.
            return .conflict(.init())
        }

        return .created(.init())
    }

    func getUploadStatus(_ input: Operations.getUploadStatus.Input) async throws -> Operations.getUploadStatus.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else { return .notFound(.init()) }
        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }
        guard try await isMember(gameId: gameId, userID: userID) else { return .forbidden(.init()) }

        guard let round = try await currentRound(gameId: gameId) else { return .notFound(.init()) }
        let roundID = try round.requireID()
        let photographers = try await RoundPhotographer.query(on: db)
            .filter(\.$round.$id == roundID)
            .all()
        let uploadedUserIDs = Set(try await Photo.query(on: db)
            .filter(\.$round.$id == roundID)
            .all()
            .map { $0.$photographer.id })

        let byTeam = Dictionary(grouping: photographers, by: { $0.$team.id })
        let status = byTeam.map { teamID, entries in
            Components.Schemas.TeamUploadStatus(
                teamId: teamID.uuidString,
                status: entries.allSatisfy { uploadedUserIDs.contains($0.$user.id) } ? .uploaded : .pending
            )
        }
        return .ok(.init(body: .json(status)))
    }
}
