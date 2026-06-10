import OpenAPIRuntime
import Vapor
import Fluent

extension APIHandler {

    private func currentUserID() throws -> UUID {
        guard let id = AuthMiddleware.currentUserID else {
            throw Abort(.unauthorized)
        }
        return id
    }

    private func mapGame(_ game: Game, on db: any Database) async throws -> Components.Schemas.Game {
        let roundCount = try await Round.query(on: db)
            .filter(\.$game.$id == game.requireID())
            .count()
        let status: Components.Schemas.GameStatus
        switch game.state {
        case .lobby:    status = .waiting
        case .running:  status = .active
        case .gameOver: status = .finished
        }
        return Components.Schemas.Game(
            id: try game.requireID().uuidString,
            code: game.code,
            status: status,
            hostId: game.$host.id.uuidString,
            totalRounds: game.totalRounds,
            currentRound: roundCount,
            maxPlayers: game.maxPlayers,
            createdAt: game.createdAt ?? Date(),
            roundDurationHours: game.roundDurationHours,
            photoViewSeconds: game.photoViewSeconds
        )
    }

    private func generateUniqueCode(on db: any Database) async throws -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var code: String
        repeat {
            code = String((0..<6).map { _ in chars.randomElement()! })
        } while try await Game.query(on: db).filter(\.$code == code).count() > 0
        return code
    }

    func createGame(_ input: Operations.createGame.Input) async throws -> Operations.createGame.Output {
        let userID = try currentUserID()
        let db = app.db

        let body: Components.Schemas.CreateGameRequest
        switch input.body {
        case .json(let b): body = b
        }

        let code = try await generateUniqueCode(on: db)
        let game = Game(
            state: .lobby,
            hostID: userID,
            code: code,
            totalRounds: body.totalRounds ?? 5,
            maxPlayers: body.maxPlayers ?? 8,
            roundDurationHours: body.roundDurationHours ?? 24,
            photoViewSeconds: body.photoViewSeconds ?? 120
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

        return .created(.init(body: .json(try await mapGame(game, on: db))))
    }

    func joinGame(_ input: Operations.joinGame.Input) async throws -> Operations.joinGame.Output {
        let userID = try currentUserID()
        let db = app.db

        let code: String
        switch input.body {
        case .json(let b): code = b.code
        }

        guard let game = try await Game.query(on: db).filter(\.$code == code).first() else {
            return .notFound(.init())
        }
        guard game.state == .lobby else { return .conflict(.init()) }
        let gameID = try game.requireID()

        let playerCount = try await TeamMember.query(on: db).filter(\.$game.$id == gameID).count()
        guard playerCount < game.maxPlayers else { return .conflict(.init()) }

        let alreadyIn = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameID)
            .filter(\.$user.$id == userID)
            .count() > 0
        guard !alreadyIn else { return .conflict(.init()) }

        let participates = try await Participate.query(on: db).filter(\.$game.$id == gameID).all()
        var teamCounts: [UUID: Int] = [:]
        for p in participates {
            teamCounts[p.$team.id] = try await TeamMember.query(on: db)
                .filter(\.$team.$id == p.$team.id)
                .filter(\.$game.$id == gameID)
                .count()
        }
        let targetTeamID = participates
            .sorted { (teamCounts[$0.$team.id] ?? 0) < (teamCounts[$1.$team.id] ?? 0) }
            .first!.$team.id

        try await TeamMember(teamID: targetTeamID, userID: userID, gameID: gameID).save(on: db)

        return .ok(.init(body: .json(try await mapGame(game, on: db))))
    }

    func getGame(_ input: Operations.getGame.Input) async throws -> Operations.getGame.Output {
        let db = app.db
        guard let gameID = UUID(uuidString: input.path.gameId),
              let game = try await Game.find(gameID, on: db) else {
            return .notFound(.init())
        }
        return .ok(.init(body: .json(try await mapGame(game, on: db))))
    }

    func startGame(_ input: Operations.startGame.Input) async throws -> Operations.startGame.Output {
        let userID = try currentUserID()
        let db = app.db
        guard let gameID = UUID(uuidString: input.path.gameId),
              let game = try await Game.find(gameID, on: db) else {
            throw Abort(.notFound)
        }
        guard game.$host.id == userID else { return .forbidden(.init()) }
        guard game.state == .lobby else { return .conflict(.init()) }

        let playerCount = try await TeamMember.query(on: db).filter(\.$game.$id == gameID).count()
        guard playerCount >= 2 else { return .conflict(.init()) }

        game.state = .running
        game.startedAt = Date()
        try await game.save(on: db)

        let deadline = Date().addingTimeInterval(Double(game.roundDurationHours) * 3600)
        try await Round(currentPhase: .uploading, gameID: gameID, roundNumber: 1, deadline: deadline).save(on: db)

        return .ok(.init(body: .json(try await mapGame(game, on: db))))
    }

    func leaveGame(_ input: Operations.leaveGame.Input) async throws -> Operations.leaveGame.Output {
        let userID = try currentUserID()
        let db = app.db
        guard let gameID = UUID(uuidString: input.path.gameId),
              let game = try await Game.find(gameID, on: db) else {
            return .notFound(.init())
        }
        guard let membership = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameID)
            .filter(\.$user.$id == userID)
            .first() else {
            return .notFound(.init())
        }
        try await membership.delete(on: db)

        if game.$host.id == userID {
            if let next = try await TeamMember.query(on: db).filter(\.$game.$id == gameID).first() {
                game.$host.id = next.$user.id
                try await game.save(on: db)
            } else {
                try await game.delete(on: db)
            }
        }
        return .noContent
    }

    func listPlayers(_ input: Operations.listPlayers.Input) async throws -> Operations.listPlayers.Output {
        let db = app.db
        guard let gameID = UUID(uuidString: input.path.gameId),
              let game = try await Game.find(gameID, on: db) else {
            return .notFound(.init())
        }
        let hostID = game.$host.id
        let members = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameID)
            .with(\.$user)
            .all()

        let players: [Components.Schemas.Player] = members.map { m in
            Components.Schemas.Player(
                id: m.$user.id.uuidString,
                username: m.user.username,
                teamId: m.$team.id.uuidString,
                isHost: m.$user.id == hostID,
                joinedAt: Date()
            )
        }
        return .ok(.init(body: .json(players)))
    }

    func kickPlayer(_ input: Operations.kickPlayer.Input) async throws -> Operations.kickPlayer.Output {
        let userID = try currentUserID()
        let db = app.db
        guard let gameID = UUID(uuidString: input.path.gameId),
              let game = try await Game.find(gameID, on: db) else {
            return .notFound(.init())
        }
        guard game.$host.id == userID else { return .forbidden(.init()) }
        guard game.state == .lobby else { return .conflict(.init()) }
        guard let playerUUID = UUID(uuidString: input.path.playerId),
              let membership = try await TeamMember.query(on: db)
                .filter(\.$game.$id == gameID)
                .filter(\.$user.$id == playerUUID)
                .first() else {
            return .notFound(.init())
        }
        try await membership.delete(on: db)
        return .noContent
    }

    func listTeams(_ input: Operations.listTeams.Input) async throws -> Operations.listTeams.Output {
        let db = app.db
        guard let gameID = UUID(uuidString: input.path.gameId),
              let game = try await Game.find(gameID, on: db) else {
            return .notFound(.init())
        }
        let hostID = game.$host.id

        let participates = try await Participate.query(on: db).filter(\.$game.$id == gameID).all()
        let teamIDs = participates.map { $0.$team.id }

        let members = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameID)
            .filter(\.$team.$id ~~ teamIDs)
            .with(\.$user)
            .all()
        var membersByTeam: [UUID: [TeamMember]] = [:]
        for m in members { membersByTeam[m.$team.id, default: []].append(m) }

        let rounds = try await Round.query(on: db).filter(\.$game.$id == gameID).all()
        let roundIDs = try rounds.map { try $0.requireID() }
        let results = roundIDs.isEmpty ? [] : try await RoundResult.query(on: db)
            .filter(\.$round.$id ~~ roundIDs)
            .all()
        var scoreByTeam: [UUID: Int] = [:]
        for r in results { scoreByTeam[r.$team.id, default: 0] += r.teamPoints }

        let teamModels = try await Team.query(on: db).filter(\.$id ~~ teamIDs).all()
        var teamByID: [UUID: Team] = [:]
        for t in teamModels { teamByID[try t.requireID()] = t }

        var teams: [Components.Schemas.Team] = []
        for p in participates {
            let teamID = p.$team.id
            guard let team = teamByID[teamID] else { continue }
            let players: [Components.Schemas.Player] = (membersByTeam[teamID] ?? []).map { m in
                Components.Schemas.Player(
                    id: m.$user.id.uuidString,
                    username: m.user.username,
                    teamId: teamID.uuidString,
                    isHost: m.$user.id == hostID,
                    joinedAt: Date()
                )
            }
            teams.append(Components.Schemas.Team(
                id: teamID.uuidString,
                name: team.name,
                players: players,
                score: scoreByTeam[teamID] ?? 0
            ))
        }
        return .ok(.init(body: .json(teams)))
    }
}
