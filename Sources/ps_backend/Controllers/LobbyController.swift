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
        let currentRound = rounds.first(where: { $0.currentPhase != .calculateResults })?.roundNumber ?? 0
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
            currentRound: currentRound,
            maxPlayers: game.maxPlayers,
            createdAt: game.createdAt ?? Date(),
            startedAt: game.startedAt,
            finishedAt: game.finishedAt,
            roundDurationHours: game.roundDurationHours,
            photoViewSeconds: game.photoViewSeconds
        )
    }

    private func generateUniqueCode() async throws -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var code: String
        repeat {
            code = String((0..<6).map { _ in chars.randomElement()! })
        } while try await Game.query(on: db).filter(\.$code == code).count() > 0
        return code
    }

    // TODO: Replace with RoundService
    private func createRounds(for game: Game) async throws {
        let gameID = try game.requireID()
        let start = Date()

        let participates = try await Participate.query(on: db).filter(\.$game.$id == gameID).all()
        var membersByTeam: [UUID: [UUID]] = [:]
        for p in participates {
            let teamID = p.$team.id
            let userIDs = try await TeamMember.query(on: db)
                .filter(\.$game.$id == gameID)
                .filter(\.$team.$id == teamID)
                .all()
                .map { $0.$user.id }
            membersByTeam[teamID] = userIDs
        }

        for n in 1...game.totalRounds {
            let deadline = start.addingTimeInterval(Double(n) * Double(game.roundDurationHours) * 3600)
            let round = Round(currentPhase: .upload, gameID: gameID, roundNumber: n, deadline: deadline)
            try await round.save(on: db)
            let roundID = try round.requireID()

            for (teamID, members) in membersByTeam {
                guard !members.isEmpty else { continue }
                let photographerID = members[(n - 1) % members.count]
                try await RoundPhotographer(roundID: roundID, teamID: teamID, userID: photographerID).save(on: db)
            }
        }
    }

    func createGame(_ input: Operations.createGame.Input) async throws -> Operations.createGame.Output {
        let userID = try currentUserID()
        switch input.body {
        case .json(let body):
            let code = try await generateUniqueCode()
            let game = Game(
                state: .lobby, hostID: userID, code: code,
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

            let allMembers = try await TeamMember.query(on: db).filter(\.$game.$id == gameID).all()
            guard allMembers.count < game.maxPlayers else { return .conflict(.init()) }
            guard !allMembers.contains(where: { $0.$user.id == userID }) else { return .conflict(.init()) }

            let participates = try await Participate.query(on: db).filter(\.$game.$id == gameID).all()
            let countByTeam = Dictionary(grouping: allMembers, by: { $0.$team.id }).mapValues { $0.count }
            guard let targetTeamID = participates
                .sorted(by: { (countByTeam[$0.$team.id] ?? 0) < (countByTeam[$1.$team.id] ?? 0) })
                .first?.$team.id else { throw Abort(.internalServerError) }

            try await TeamMember(teamID: targetTeamID, userID: userID, gameID: gameID).save(on: db)
            return .ok(.init(body: .json(try await mapGame(game))))
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

        game.state = .running
        game.startedAt = Date()
        try await game.save(on: db)
        try await createRounds(for: game)

        return .ok(.init(body: .json(try await mapGame(game))))
    }

    func leaveGame(_ input: Operations.leaveGame.Input) async throws -> Operations.leaveGame.Output {
        let userID = try currentUserID()
        let game = try await findGame(id: input.path.gameId)
        let gameID = try game.requireID()

        guard game.state == .lobby else { return .conflict(.init()) }
        guard let membership = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameID)
            .filter(\.$user.$id == userID)
            .first() else { return .notFound(.init()) }
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
        guard let playerUUID = UUID(uuidString: input.path.playerId),
              let membership = try await TeamMember.query(on: db)
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
}
