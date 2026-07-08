import OpenAPIRuntime
import Vapor
import Fluent

extension APIHandler {

    private var db: any Database { app.db }

    private func currentUserID() throws -> UUID {
        guard let id = AuthMiddleware.currentUserID else { throw Abort(.unauthorized) }
        return id
    }

    private func findGame(id: String) async throws -> Game {
        guard let uuid = UUID(uuidString: id), let game = try await Game.find(uuid, on: db) else {
            throw Abort(.notFound)
        }
        return game
    }

    private func mapPlayer(_ member: TeamMember, hostID: UUID) -> Components.Schemas.Player {
        Components.Schemas.Player(
            id: member.$user.id.uuidString,
            username: member.user.username,
            teamId: member.$team.id.uuidString,
            isHost: member.$user.id == hostID,
            joinedAt: member.joinedAt ?? Date()
        )
    }

    private func mapGame(_ game: Game) async throws -> Components.Schemas.Game {
        let rounds = try await Round.query(on: db)
            .filter(\.$game.$id == game.requireID())
            .sort(\.$roundNumber, .ascending)
            .all()
        let currentRound = rounds.first(where: { $0.currentPhase != .calculateResults })?.roundNumber
            ?? (game.state == .running ? game.totalRounds : 0)
        let status: Components.Schemas.GameStatus
        switch game.state {
        case .lobby:    status = .waiting
        case .running:  status = .active
        case .gameOver: status = .finished
        }
        return Components.Schemas.Game(
            id: try game.requireID().uuidString,
            code: game.code,
            name: game.name,
            status: status,
            hostId: game.$host.id.uuidString,
            totalRounds: game.totalRounds,
            currentRound: currentRound,
            maxPlayers: game.maxPlayers,
            createdAt: game.createdAt ?? Date(),
            startedAt: game.startedAt,
            finishedAt: game.finishedAt,
            uploadPhaseSeconds: game.uploadPhaseSeconds,
            guessingPhaseSeconds: game.guessingPhaseSeconds,
            photoViewSeconds: game.photoViewSeconds,
            setMarkerSeconds: game.setMarkerSeconds
        )
    }

    private func generateUniqueCode() async throws -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        for _ in 0..<10 {
            let code = String((0..<6).map { _ in chars.randomElement()! })
            if try await Game.query(on: db).filter(\.$code == code).count() == 0 {
                return code
            }
        }
        throw Abort(.internalServerError)
    }

    // TODO: Replace with RoundService
    private func createRounds(for game: Game, on db: any Database) async throws {
        let gameID = try game.requireID()
        let roundDuration = TimeInterval(game.uploadPhaseSeconds)

        let allMembers = try await TeamMember.query(on: db).filter(\.$game.$id == gameID).all()
        let membersByTeam = Dictionary(grouping: allMembers, by: { $0.$team.id })
            .mapValues { $0.map { $0.$user.id } }

        for n in 1...game.totalRounds {
            let deadline = n == 1 ? Date().addingTimeInterval(roundDuration) : nil
            let round = Round(currentPhase: .upload, gameID: gameID, roundNumber: n, deadline: deadline)
            try await round.save(on: db)
            let roundID = try round.requireID()

            for (teamID, members) in membersByTeam {
                guard !members.isEmpty else { continue }
                let photographerID = members[(n - 1) % members.count]
                try await RoundPhotographer(roundID: roundID, teamID: teamID, userID: photographerID).save(on: db)
                try await RoundResult(roundID: roundID, teamID: teamID, teamPoints: 0).save(on: db)
            }
        }
    }

    /// Erlaubter Wertebereich für die optionalen Phasen-Sekunden-Overrides (Demo-Spiele).
    private static let phaseSecondsRange = 5...86400

    /// nil = keine Overrides gültig verwendbar (weder komplett fehlend noch komplett vorhanden, oder außerhalb phaseSecondsRange)
    private func resolvePhaseDurations(
        uploadPhaseSeconds: Int?, guessingPhaseSeconds: Int?,
        photoViewSeconds: Int?, setMarkerSeconds: Int?
    ) -> (uploadPhaseSeconds: Int, guessingPhaseSeconds: Int, photoViewSeconds: Int, setMarkerSeconds: Int)? {
        let overrides = [uploadPhaseSeconds, guessingPhaseSeconds, photoViewSeconds, setMarkerSeconds]

        guard overrides.contains(where: { $0 != nil }) else {
            return (uploadPhaseSeconds: 86400, guessingPhaseSeconds: 86400, photoViewSeconds: 300, setMarkerSeconds: 300)
        }

        guard let uploadPhaseSeconds, let guessingPhaseSeconds, let photoViewSeconds, let setMarkerSeconds else {
            return nil
        }

        for value in overrides.compactMap({ $0 }) {
            guard Self.phaseSecondsRange.contains(value) else { return nil }
        }

        return (uploadPhaseSeconds, guessingPhaseSeconds, photoViewSeconds, setMarkerSeconds)
    }

    func createGame(_ input: Operations.createGame.Input) async throws -> Operations.createGame.Output {
        let userID = try currentUserID()
        switch input.body {
        case .json(let body):
            guard let durations = resolvePhaseDurations(
                uploadPhaseSeconds: body.uploadPhaseSeconds,
                guessingPhaseSeconds: body.guessingPhaseSeconds,
                photoViewSeconds: body.photoViewSeconds,
                setMarkerSeconds: body.setMarkerSeconds
            ) else {
                return .badRequest(.init())
            }
            let code = try await generateUniqueCode()
            let game = Game(
                state: .lobby, hostID: userID, code: code,
                name: body.name,
                totalRounds: 5,
                maxPlayers: 8,
                uploadPhaseSeconds: durations.uploadPhaseSeconds,
                guessingPhaseSeconds: durations.guessingPhaseSeconds,
                photoViewSeconds: durations.photoViewSeconds,
                setMarkerSeconds: durations.setMarkerSeconds
            )
            try await game.save(on: db)
            let gameID = try game.requireID()

            let teamA = Team(name: "Team A")
            let teamB = Team(name: "Team B")
            try await teamA.save(on: db)
            try await teamB.save(on: db)
            try await Participate(gameID: gameID, teamID: teamA.requireID(), isWinner: false).save(on: db)
            try await Participate(gameID: gameID, teamID: teamB.requireID(), isWinner: false).save(on: db)
            try await TeamMember(teamID: teamA.requireID(), userID: userID, gameID: gameID).save(on: db)

            return .created(.init(body: .json(try await mapGame(game))))
        }
    }

    func joinGame(_ input: Operations.joinGame.Input) async throws -> Operations.joinGame.Output {
        let userID = try currentUserID()
        switch input.body {
        case .json(let body):
            guard let game = try await Game.query(on: db).filter(\.$code == body.code).first() else {
                return .notFound(.init())
            }
            guard game.state == .lobby else { return .conflict(.init()) }
            let gameID = try game.requireID()

            enum JoinOutcome { case ok, conflict, internalError }
            let outcome: JoinOutcome = try await db.transaction { db in
                let allMembers = try await TeamMember.query(on: db).filter(\.$game.$id == gameID).all()
                guard allMembers.count < game.maxPlayers else { return .conflict }
                guard !allMembers.contains(where: { $0.$user.id == userID }) else { return .conflict }

                let participates = try await Participate.query(on: db).filter(\.$game.$id == gameID).all()
                let countByTeam = Dictionary(grouping: allMembers, by: { $0.$team.id }).mapValues { $0.count }
                guard let targetTeamID = participates
                    .sorted(by: { (countByTeam[$0.$team.id] ?? 0) < (countByTeam[$1.$team.id] ?? 0) })
                    .first?.$team.id else { return .internalError }

                try await TeamMember(teamID: targetTeamID, userID: userID, gameID: gameID).save(on: db)
                return .ok
            }
            switch outcome {
            case .conflict: return .conflict(.init())
            case .internalError: throw Abort(.internalServerError)
            case .ok: return .ok(.init(body: .json(try await mapGame(game))))
            }
        }
    }

    func getGame(_ input: Operations.getGame.Input) async throws -> Operations.getGame.Output {
        let game = try await findGame(id: input.path.gameId)
        return .ok(.init(body: .json(try await mapGame(game))))
    }

    func startGame(_ input: Operations.startGame.Input) async throws -> Operations.startGame.Output {
        let userID = try currentUserID()
        let game = try await findGame(id: input.path.gameId)
        guard game.$host.id == userID else { return .forbidden(.init()) }
        guard game.state == .lobby else { return .conflict(.init()) }

        let gameID = try game.requireID()
        let playerCount = try await TeamMember.query(on: db).filter(\.$game.$id == gameID).count()
        guard playerCount >= 2 else { return .conflict(.init()) }

        try await db.transaction { db in
            game.state = .running
            game.startedAt = Date()
            try await game.save(on: db)
            try await self.createRounds(for: game, on: db)
        }

        return .ok(.init(body: .json(try await mapGame(game))))
    }

    func leaveGame(_ input: Operations.leaveGame.Input) async throws -> Operations.leaveGame.Output {
        let userID = try currentUserID()
        let game = try await findGame(id: input.path.gameId)
        let gameID = try game.requireID()

        guard game.state == .lobby else { return .conflict(.init()) }

        enum LeaveOutcome { case ok, notFound }
        let outcome: LeaveOutcome = try await db.transaction { db in
            guard let membership = try await TeamMember.query(on: db)
                .filter(\.$game.$id == gameID)
                .filter(\.$user.$id == userID)
                .first() else { return .notFound }
            try await membership.delete(on: db)

            if game.$host.id == userID {
                if let next = try await TeamMember.query(on: db)
                    .filter(\.$game.$id == gameID)
                    .sort(\.$joinedAt, .ascending)
                    .first() {
                    game.$host.id = next.$user.id
                    try await game.save(on: db)
                } else {
                    try await game.delete(on: db)
                }
            }
            return .ok
        }
        return outcome == .notFound ? .notFound(.init()) : .noContent
    }

    func listPlayers(_ input: Operations.listPlayers.Input) async throws -> Operations.listPlayers.Output {
        let game = try await findGame(id: input.path.gameId)
        let gameID = try game.requireID()
        let members = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameID)
            .with(\.$user)
            .all()
        return .ok(.init(body: .json(members.map { mapPlayer($0, hostID: game.$host.id) })))
    }

    func kickPlayer(_ input: Operations.kickPlayer.Input) async throws -> Operations.kickPlayer.Output {
        let userID = try currentUserID()
        let game = try await findGame(id: input.path.gameId)
        guard game.$host.id == userID else { return .forbidden(.init()) }
        guard game.state == .lobby else { return .conflict(.init()) }

        let gameID = try game.requireID()
        guard let playerUUID = UUID(uuidString: input.path.playerId) else { return .notFound(.init()) }
        guard playerUUID != userID else { return .forbidden(.init()) }
        guard let membership = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameID)
            .filter(\.$user.$id == playerUUID)
            .first() else { return .notFound(.init()) }
        try await membership.delete(on: db)
        return .noContent
    }

    func listTeams(_ input: Operations.listTeams.Input) async throws -> Operations.listTeams.Output {
        let game = try await findGame(id: input.path.gameId)
        let gameID = try game.requireID()
        let hostID = game.$host.id

        let participates = try await Participate.query(on: db).filter(\.$game.$id == gameID).all()
        let teamIDs = participates.map { $0.$team.id }

        let members = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameID)
            .filter(\.$team.$id ~~ teamIDs)
            .with(\.$user)
            .all()
        let membersByTeam = Dictionary(grouping: members, by: { $0.$team.id })

        let roundIDs = try await Round.query(on: db).filter(\.$game.$id == gameID).all()
            .map { try $0.requireID() }
        let results = roundIDs.isEmpty ? [] : try await RoundResult.query(on: db)
            .filter(\.$round.$id ~~ roundIDs)
            .all()
        let scoreByTeam = results.reduce(into: [UUID: Int]()) { $0[$1.$team.id, default: 0] += $1.teamPoints }

        let teamByID = try await Team.query(on: db).filter(\.$id ~~ teamIDs).all()
            .reduce(into: [UUID: Team]()) { dict, t in dict[try t.requireID()] = t }

        let teams = participates.compactMap { p -> Components.Schemas.Team? in
            let teamID = p.$team.id
            guard let team = teamByID[teamID] else { return nil }
            return Components.Schemas.Team(
                id: teamID.uuidString,
                name: team.name,
                players: (membersByTeam[teamID] ?? []).map { mapPlayer($0, hostID: hostID) },
                score: scoreByTeam[teamID] ?? 0
            )
        }
        return .ok(.init(body: .json(teams)))
    }

    func getGamesForPlayer(_ input: Operations.getGamesForPlayer.Input) async throws -> Operations.getGamesForPlayer.Output {
        guard let playerUUID = UUID(uuidString: input.path.playerId) else { throw Abort(.badRequest) }
        let memberships = try await TeamMember.query(on: db)
            .filter(\.$user.$id == playerUUID)
            .all()
        let gameIDs = memberships.map { $0.$game.id.uuidString }
        return .ok(.init(body: .json(gameIDs)))
    }
}
