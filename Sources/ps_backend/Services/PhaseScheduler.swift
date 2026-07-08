import Queues
import Vapor
import Fluent

struct PhaseScheduler: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        let db = context.application.db
        let rounds = try await Round.query(on: db)
            .filter(\.$deadline < Date())
            .all()

        //phase switches - upload -> guess -> calculateResults
        for round in rounds {
            let game = try await round.$game.get(on: db)

            switch round.currentPhase {
            case .upload:
                round.currentPhase = .guess
                round.deadline = Date().addingTimeInterval(Double(game.guessingPhaseSeconds))
                try await round.save(on: db)
            case .guess:
                round.currentPhase = .calculateResults
                round.deadline = nil
                try await round.save(on: db)
                try await resolveRoundResults(for: round, on: db)
                if round.roundNumber == game.totalRounds {
                    try await finishGame(game, on: db)
                } else {
                    try await activateNextRound(after: round, game: game, on: db)
                }
            case .calculateResults:
                break
            }
        }
    }

    /// Setzt die Upload-Deadline der nächsten Runde, damit sie beim nächsten Tick vom
    /// Scheduler erfasst wird - ohne das bleibt jede Runde nach der ersten für immer
    /// in "upload" mit deadline=nil hängen (deadline < Date()-Filter erfasst sie nie).
    private func activateNextRound(after round: Round, game: Game, on db: any Database) async throws {
        guard let nextRound = try await Round.query(on: db)
            .filter(\.$game.$id == round.$game.id)
            .filter(\.$roundNumber == round.roundNumber + 1)
            .first() else { return }

        nextRound.deadline = Date().addingTimeInterval(Double(game.uploadPhaseSeconds))
        try await nextRound.save(on: db)
    }

    /// Team-Punkte je Runde: eigenes Foto fehlt -> 0 P, Gegner-Foto fehlt -> 10 P,
    /// sonst Durchschnitt der Guess-Punkte (0-10, siehe Scoring) der eigenen Spieler.
    private func resolveRoundResults(for round: Round, on db: any Database) async throws {
        let roundID = try round.requireID()
        let gameID = round.$game.id

        let photographers = try await RoundPhotographer.query(on: db)
            .filter(\.$round.$id == roundID)
            .all()
        let teamIDs = Array(Set(photographers.map { $0.$team.id }))
        guard teamIDs.count == 2 else { return }

        let photographerByTeam = Dictionary(uniqueKeysWithValues: photographers.map { ($0.$team.id, $0.$user.id) })
        let uploadedUserIDs = Set(try await Photo.query(on: db)
            .filter(\.$round.$id == roundID)
            .all()
            .map { $0.$photographer.id })

        let members = try await TeamMember.query(on: db).filter(\.$game.$id == gameID).all()
        let teamByUser = Dictionary(uniqueKeysWithValues: members.map { ($0.$user.id, $0.$team.id) })

        let guesses = try await Guess.query(on: db).filter(\.$round.$id == roundID).all()
        var guessPointsByTeam: [UUID: [Int]] = [:]
        for guess in guesses {
            guard let teamID = teamByUser[guess.$user.id] else { continue }
            guessPointsByTeam[teamID, default: []].append(guess.points ?? 0)
        }

        let (teamA, teamB) = (teamIDs[0], teamIDs[1])
        let uploadedA = photographerByTeam[teamA].map { uploadedUserIDs.contains($0) } ?? false
        let uploadedB = photographerByTeam[teamB].map { uploadedUserIDs.contains($0) } ?? false

        try await updateRoundResult(
            roundID: roundID, teamID: teamA,
            points: teamPoints(ownUploaded: uploadedA, opponentUploaded: uploadedB, guessPoints: guessPointsByTeam[teamA] ?? []),
            on: db
        )
        try await updateRoundResult(
            roundID: roundID, teamID: teamB,
            points: teamPoints(ownUploaded: uploadedB, opponentUploaded: uploadedA, guessPoints: guessPointsByTeam[teamB] ?? []),
            on: db
        )
    }

    private func teamPoints(ownUploaded: Bool, opponentUploaded: Bool, guessPoints: [Int]) -> Int {
        guard ownUploaded else { return 0 }
        guard opponentUploaded else { return 10 }
        guard !guessPoints.isEmpty else { return 0 }
        return Int((Double(guessPoints.reduce(0, +)) / Double(guessPoints.count)).rounded())
    }

    private func updateRoundResult(roundID: UUID, teamID: UUID, points: Int, on db: any Database) async throws {
        guard let result = try await RoundResult.query(on: db)
            .filter(\.$round.$id == roundID)
            .filter(\.$team.$id == teamID)
            .first() else { return }
        result.teamPoints = points
        try await result.save(on: db)
    }

    private func finishGame(_ game: Game, on db: any Database) async throws {
        let gameID = try game.requireID()
        let rounds = try await Round.query(on: db).filter(\.$game.$id == gameID).all()
        let roundIDs = try rounds.map { try $0.requireID() }
        let results = try await RoundResult.query(on: db).filter(\.$round.$id ~~ roundIDs).all()
        let scoreByTeam = results.reduce(into: [UUID: Int]()) { $0[$1.$team.id, default: 0] += $1.teamPoints }

        let participates = try await Participate.query(on: db).filter(\.$game.$id == gameID).all()
        let maxScore = scoreByTeam.values.max()
        let topTeams = scoreByTeam.filter { $0.value == maxScore }
        let winnerTeamID = topTeams.count == 1 ? topTeams.first?.key : nil

        for participate in participates {
            participate.isWinner = (participate.$team.id == winnerTeamID)
            try await participate.save(on: db)
        }

        game.state = .gameOver
        game.finishedAt = Date()
        try await game.save(on: db)
    }
}
