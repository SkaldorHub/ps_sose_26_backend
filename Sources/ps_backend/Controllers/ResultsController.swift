import OpenAPIRuntime
import Vapor
import Foundation
import Fluent

extension APIHandler {

    private var db: any Database { app.db }

    /// Ohne diesen Check kann jeder registrierte Account Ergebnisse/Standorte/Punktzahlen
    /// eines beliebigen fremden Spiels abrufen, sofern die gameId bekannt ist. Gibt bewusst Bool
    /// statt throw Abort(...) zurück: ein direkt geworfener Abort-Fehler wird von der OpenAPI-
    /// Server-Transportschicht innerhalb eines Operation-Handlers nicht auf den richtigen HTTP-
    /// Status gemappt, sondern generisch als 500 "Something went wrong" beantwortet - nur
    /// typisierte Operation-Outputs (.forbidden(.init())) liefern den korrekten Statuscode.
    private func isMember(gameId: UUID, userID: UUID) async throws -> Bool {
        try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameId)
            .filter(\.$user.$id == userID)
            .first() != nil
    }

    /// Holt die aktuellste Runde, prüft ob calculateResults ist, holt dann Foto und alle Guesses, gibt aktuelles Ergebnis zurück.
    func getCurrentResult(_ input: Operations.getCurrentResult.Input) async throws -> Operations.getCurrentResult.Output {
        guard let gameId = UUID(uuidString: input.path.gameId),
              let roundId = UUID(uuidString: input.query.roundId) else {
            return .notFound(.init())
        }

        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }
        guard try await isMember(gameId: gameId, userID: userID) else { return .forbidden(.init()) }

        // Explizit über roundId statt implizit "die zuletzt abgeschlossene Runde" zu erraten -
        // verhindert, dass ein Client kurz nach einem Rundenwechsel noch das Ergebnis der
        // vorherigen Runde bekommt (siehe GuessController.round(id:gameId:)).
        guard let round = try await Round.query(on: db)
            .filter(\.$id == roundId)
            .filter(\.$game.$id == gameId)
            .first(),
            round.currentPhase == .calculateResults
        else {
            return .notFound(.init())
        }

        // Foto der aktuellen Runde holen, um den tatsächlichen Standort zu bekommen
        let photo = try await Photo.query(on: db)
            .filter(\.$round.$id == round.requireID())
            .first()

        guard let photo = photo else {
            return .notFound(.init())
        }

        // Alle Guesses der aktuellen Runde holen
        let guesses = try await Guess.query(on: db)
            .filter(\.$round.$id == round.requireID())
            .all()

        var guessResults: [Components.Schemas.GuessResult] = []
        for guess in guesses {
            let teamMember = try await TeamMember.query(on: db)
                .filter(\.$user.$id == guess.$user.id)
                .filter(\.$game.$id == gameId)
                .first()
            guard let teamMember = teamMember else { continue }
            guessResults.append(Components.Schemas.GuessResult(
                teamId: teamMember.$team.id.uuidString,
                playerId: guess.$user.id.uuidString,
                lat: guess.latitude,
                lng: guess.longitude,
                distanceMeters: guess.distance ?? 0,
                teamPoints: guess.points ?? 0
            ))
        }

        return .ok(.init(body: .json(.init(
            roundNumber: round.roundNumber,
            actualLat: photo.latitude,
            actualLng: photo.longitude,
            guesses: guessResults
        ))))
    }

    /// Hilfsmethode zum berechnen von den Scores aller Teams eines Spiels
    private func calculateLeaderboard(gameId: UUID) async throws -> [Components.Schemas.LeaderboardEntry] {
        // gibt Teams zurück die Teil des Spiels sind
        let teamsFromThisGame = try await Participate.query(on: db)
            .filter(\.$game.$id == gameId)
            .all()

        // gibt alle Runden zurück die zu diesem Spiel gehören
        let rounds = try await Round.query(on: db)
            .filter(\.$game.$id == gameId)
            .all()

        // Array aus RundenIds
        let roundIds = try rounds.map { try $0.requireID() }

        // Array bestehend aus Team und Score von Team
        var leaderboard: [Components.Schemas.LeaderboardEntry] = []
        for participate in teamsFromThisGame {
            // Team-Objekt zum aktuellen Participate-Eintrag holen
            let team = try await Team.query(on: db)
                .filter(\.$id == participate.$team.id)
                .first()

            guard let team = team else {
                throw Abort(.notFound)
            }

            // Alle Rundenergebnisse dieses Teams für die Runden dieses Spiels holen
            let roundResults = try await RoundResult.query(on: db)
                .filter(\.$team.$id == participate.$team.id)
                .filter(\.$round.$id ~~ roundIds)
                .all()

            // Punkte aller Runden aufsummieren
            let gameResult = roundResults.reduce(0) { $0 + $1.teamPoints }
            leaderboard.append(Components.Schemas.LeaderboardEntry(
                teamId: try team.requireID().uuidString,
                teamName: team.name,
                score: gameResult
            ))
        }
        return leaderboard
    }

    /// gibt Leaderboard zurück
    func getLeaderboard(_ input: Operations.getLeaderboard.Input) async throws -> Operations.getLeaderboard.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else {
            return .notFound(.init())
        }

        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }
        guard try await isMember(gameId: gameId, userID: userID) else { return .forbidden(.init()) }

        let leaderboard = try await calculateLeaderboard(gameId: gameId)

        return .ok(.init(body: .json(leaderboard)))
    }

    /// Durchschnittsdistanz/-punkte je Spieler über alle Runden des Spiels (nicht nur die
    /// aktuelle Runde). MVP = Spieler mit den meisten Durchschnittspunkten, sofern überhaupt
    /// mindestens ein Tipp mit Punkten existiert (sonst kein MVP statt eines zufälligen bei
    /// lauter 0en).
    private func calculatePlayerResults(gameId: UUID) async throws -> [Components.Schemas.PlayerResult] {
        let rounds = try await Round.query(on: db).filter(\.$game.$id == gameId).all()
        let roundIds = try rounds.map { try $0.requireID() }

        let guesses = try await Guess.query(on: db).filter(\.$round.$id ~~ roundIds).all()
        let guessesByUser = Dictionary(grouping: guesses, by: { $0.$user.id })

        let members = try await TeamMember.query(on: db)
            .filter(\.$game.$id == gameId)
            .with(\.$user)
            .all()

        var results = members.map { member -> Components.Schemas.PlayerResult in
            let userGuesses = guessesByUser[member.$user.id] ?? []
            let distances = userGuesses.compactMap(\.distance)
            let points = userGuesses.compactMap(\.points)
            let averageDistance = distances.isEmpty ? 0 : distances.reduce(0, +) / Double(distances.count)
            let averagePoints = points.isEmpty ? 0 : Double(points.reduce(0, +)) / Double(points.count)

            return Components.Schemas.PlayerResult(
                playerId: member.$user.id.uuidString,
                username: member.user.username,
                isMVP: false,
                averageDistanceMeters: averageDistance,
                averagePoints: averagePoints
            )
        }

        if let maxPoints = results.map(\.averagePoints).max(), maxPoints > 0,
           let mvpIndex = results.firstIndex(where: { $0.averagePoints == maxPoints }) {
            results[mvpIndex].isMVP = true
        }

        return results
    }

    /// Findet Team mit höchstem Score und bestimmt das Team als Gewinner, gibt Leaderboard und Gewinner zurück
    func getGameResult(_ input: Operations.getGameResult.Input) async throws -> Operations.getGameResult.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else {
            return .notFound(.init())
        }

        guard let userID = AuthMiddleware.currentUserID else { return .unauthorized(.init()) }
        guard try await isMember(gameId: gameId, userID: userID) else { return .forbidden(.init()) }

        let leaderboard = try await calculateLeaderboard(gameId: gameId)
        let players = try await calculatePlayerResults(gameId: gameId)

        // Team mit dem höchsten Score als Gewinner bestimmen (kein Gewinner bei Gleichstand)
        let maxScore = leaderboard.map(\.score).max()
        let topTeams = leaderboard.filter { $0.score == maxScore }
        let winnerTeamId = topTeams.count == 1 ? topTeams.first?.teamId : nil

        return .ok(.init(body: .json(.init(
            winnerTeamId: winnerTeamId,
            players: players,
            leaderboard: leaderboard
        ))))
    }
}