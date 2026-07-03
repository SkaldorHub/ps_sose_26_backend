import OpenAPIRuntime
import Vapor
import Fluent

extension APIHandler {

    private var db: any Database { app.db }

    private func currentUserID() throws -> UUID {
        guard let id = AuthMiddleware.currentUserID else { throw Abort(.unauthorized) }
        return id
    }

    private func currentRound(gameId: UUID) async throws -> Round? {
        try await Round.query(on: db)
            .filter(\.$game.$id == gameId)
            .sort(\.$roundNumber, .ascending)
            .all()
            .first { $0.currentPhase != .calculateResults }
    }

    func getCurrentRound(_ input: Operations.getCurrentRound.Input) async throws -> Operations.getCurrentRound.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else { return .notFound(.init()) }
        _ = try currentUserID()

        guard let game = try await Game.find(gameId, on: db) else { return .notFound(.init()) }
        guard game.state == .running else { return .conflict(.init()) }

        guard let round = try await currentRound(gameId: gameId) else { return .notFound(.init()) }
        let photographers = try await RoundPhotographer.query(on: db)
            .filter(\.$round.$id == round.requireID())
            .all()

        return .ok(.init(body: .json(.init(
            id: try round.requireID().uuidString,
            roundNumber: round.roundNumber,
            phase: Components.Schemas.RoundPhase(rawValue: round.currentPhase.rawValue)!,
            deadline: round.deadline,
            photographers: photographers.map {
                .init(teamId: $0.$team.id.uuidString, userId: $0.$user.id.uuidString)
            }
        ))))
    }

    func uploadPhoto(_ input: Operations.uploadPhoto.Input) async throws -> Operations.uploadPhoto.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else { return .notFound(.init()) }
        let userID = try currentUserID()

        guard case let .multipartForm(form) = input.body else { throw Abort(.badRequest) }
        var photoBytes: [UInt8] = []
        var lat: Double?
        var lng: Double?
        var hint: String?
        for try await part in form {
            switch part {
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
        guard let lat, let lng, !photoBytes.isEmpty else { return .forbidden(.init()) }

        guard let round = try await currentRound(gameId: gameId) else { return .notFound(.init()) }
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
        try await photo.save(on: db)

        return .created(.init())
    }

    func getUploadStatus(_ input: Operations.getUploadStatus.Input) async throws -> Operations.getUploadStatus.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else { return .notFound(.init()) }
        _ = try currentUserID()

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
