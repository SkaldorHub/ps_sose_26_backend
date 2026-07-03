import Queues
import Vapor
import Fluent

struct PhaseScheduler: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        let db = context.application.db
        let rounds = try await Round.query(on: db)
            .filter(\.$deadline < Date())
            .all()
        
        //phase switches - upload -> guess -> calculateReults
        for round in rounds {
            let game = try await round.$game.get(on: db)

            switch round.currentPhase {
            case .upload:
                round.currentPhase = .guess
                round.deadline = Date().addingTimeInterval(Double(game.photoViewSeconds))
                try await round.save(on: db)
            case .guess:
                round.currentPhase = .calculateResults
                round.deadline = nil
                try await round.save(on: db)
            case .calculateResults:
                break
            }
        }
    }
}