import OpenAPIRuntime
import Vapor
import Foundation
import Fluent

extension APIHandler {

    func getCurrentResult(_ input: Operations.getCurrentResult.Input) async throws -> Operations.getCurrentResult.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else {
            throw Abort(.notFound)
        }

        guard let userId = nil as UUID? // TODO: get from JWT
        else {
            throw Abort(.unauthorized)
        }

        // Nach gameID filtern um alle Runden für das aktuelle Game zu finden und dann Runden absteigend sortieren, um die aktuelle Runde zu erhalten
        let round = try await Round.query(on: req.db)
            .filter(\.$game.$id == gameId)
            .sort(\.$roundNumber, .descending)
            .first()

        guard let round = round else {
            throw Abort(.notFound)
        }

        // Foto der aktuellen Runde holen, um den tatsächlichen Standort zu bekommen
        let photo = try await Photo.query(on: req.db)
            .filter(\.$round.$id == round.requireID())
            .first()

        guard let photo = photo else {
            throw Abort(.notFound)
        }

        // Alle Guesses der aktuellen Runde holen
        let guesses = try await Guess.query(on: req.db)
            .filter(\.$round.$id == round.requireID())
            .all()

        let guessResults = guesses.map { guess in
            Components.Schemas.GuessResult(
                playerId: guess.$user.id,
                lat: guess.latitude,
                lng: guess.longitude,
                distanceMeters: guess.distance ?? 0,
                points: guess.points
            )
        }

        // sicherstellen, dass ein gültiges Ergebnis vorhanden ist 
        if round.currentPhase == .roundOver {
            return .ok(.init(body: .json(.init(
                roundNumber: round.roundNumber,
                actualLat: photo.latitude,
                actualLng: photo.longitude,
                guesses: guessResults
            ))))
        } else {
            throw Abort(.notFound) 
        }
    }

    /// Hilfsmethode zum berechnen von den Scores aller Teams eines Spiels
    private func calculateLeaderboard(gameId: UUID) async throws -> [Components.Schemas.LeaderboardEntry] {
        // gibt 2 teams zurück die Teil des Spiels sind
        let teamsFromThisGame = try await Participate.query(on: req.db)
            .filter(\.$game.$id == gameId)
            .all()

        // gibt alle Runden zurück die zu diesem Spiel gehören
        let round = try await Round.query(on: req.db)
            .filter(\.$game.$id == gameId)
            .all()

        // Array aus RundenIds 
        let roundIds = try round.map { try $0.requireID() }

        // Array bestehend aus Team und Score von Team
        let leaderboard = try await teamsFromThisGame.asyncMap { participate in
            // Team-Objekt zum aktuellen Participate-Eintrag holen
            let team = try await Team.query(on: req.db)
                .filter(\.$id == participate.$team.id)
                .first()

            guard let team = team else {
                throw Abort(.notFound)
            }

            // Alle Rundenergebnisse dieses Teams für die Runden dieses Spiels holen
            let roundResults = try await RoundResult.query(on: req.db)
                .filter(\.$team.$id == participate.$team.id)
                .filter(\.$round.$id ~~ roundIds)
                .all()

            // Punkte aller Runden aufsummieren
            let gameResult = roundResults.reduce(0) { $0 + $1.teamPoints }

            return Components.Schemas.LeaderboardEntry(
                teamId: try team.requireID(),
                teamName: team.name,
                score: gameResult
            )
        }
        return leaderboard
    }
    
    func getLeaderboard(_ input: Operations.getLeaderboard.Input) async throws -> Operations.getLeaderboard.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else {
            throw Abort(.notFound)
        }

        guard let userId = nil as UUID? // TODO: get from JWT
        else {
            throw Abort(.unauthorized)
        }

        let leaderboard = try await calculateLeaderboard(gameId: gameId)
    
        return .ok(.init(body: .json(leaderboard)))
    }


    func getGameResult(_ input: Operations.getGameResult.Input) async throws -> Operations.getGameResult.Output {
        guard let gameId = UUID(uuidString: input.path.gameId) else {
            throw Abort(.notFound)
        }
        
         guard let userId = nil as UUID? // TODO: get from JWT
         else {
            throw Abort(.unauthorized)
        }

        let leaderboard = try await calculateLeaderboard(gameId: gameId)

        // Team mit dem höchsten Score als Gewinner bestimmen
        let winner = leaderboard.max(by: { $0.score < $1.score })

        guard let winner = winner else { 
            throw Abort(.notFound)
        }

        return .ok(.init (body: .json(.init(
            winnerTeamId: winner.teamId,
            leaderboard: leaderboard
        ))))
    }
}