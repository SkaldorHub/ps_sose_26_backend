import Fluent
import Foundation

struct RoundService {
    let db: any Database

    /// Liefert die aktuelle Runde eines Spiels.
    func getCurrentRound(gameId: UUID) async throws -> Round? {
    try await Round.query(on: db)
        .filter(\Round.$game.$id, .equal, gameId)
        .filter(\Round.$currentPhase, .notEqual, Round.CurrentPhase.calculateResults)
        .sort(\Round.$roundNumber, .ascending)
        .first()
}

    /// Prüft ob beide Teams für die gegebene Runde bereits ein Foto hochgeladen haben.
    /// Falls ja, ist die UploadPhase faktisch beendet und die Runde wird auf .guess gesetzt.
    func checkBothTeamsUploaded(gameId: UUID, round: Round) async throws {
        guard round.currentPhase == .upload, let roundId = round.id else { return }

        let participates = try await Participate.query(on: db)
            .filter(\Participate.$game.$id, .equal, gameId)
            .all()
        guard participates.count == 2 else { return }

        let photos = try await Photo.query(on: db)
            .filter(\Photo.$round.$id, .equal, roundId)
            .all()

        var photographerTeamIds = Set<UUID>()
        for photo in photos {
            if let teamMember = try await TeamMember.query(on: db)
                .filter(\TeamMember.$user.$id, .equal, photo.$photographer.id)
                .filter(\TeamMember.$game.$id, .equal, gameId)
                .first()
            {
                photographerTeamIds.insert(teamMember.$team.id)
            }
        }

        let teamAId = participates[0].$team.id
        let teamBId = participates[1].$team.id
        let bothUploaded = photographerTeamIds.contains(teamAId) && photographerTeamIds.contains(teamBId)

        if bothUploaded {
            let game = try await round.$game.get(on: db)
            round.currentPhase = .guess
            round.deadline = Date().addingTimeInterval(Double(game.photoViewSeconds))
            try await round.save(on: db)
        }
    }
}