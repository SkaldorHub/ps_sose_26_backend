import Foundation
import OpenAPIRuntime
import OpenAPIVapor
import Vapor

extension APIHandler {

    func getTeamPhoto(_ input: Operations.getTeamPhoto.Input) async throws
        -> Operations.getTeamPhoto.Output
    {
        .undocumented(statusCode: 501, .init())
    }

    @Sendable
    public func submitGuess(_ input: Operations.submitGuess.Input) async throws
        -> Operations.submitGuess.Output
    {
        // 1. How to get the path parameters
        //let gameId = input.path.gameId  // This comes from your #/components/parameters/GameId

        // 2. How to get the JSON request body
        // The body is treated as an enum because content-types can vary, so we unpack the .json case
        // Unpack the JSON case from the body enum
        guard case .json(let requestBody) = input.body else {
            // Return a 400 or handle unexpected content type
            throw Abort(.badRequest)
        }

        let latitude = requestBody.lat
        let longitude = requestBody.lng


        // get User ID
        // get Game ID
        // get current round ID

        // let user = User(
        //     username: "testuser",
        //     passwordHash: "testhash"
        // )

        // try await user.save(on: app.db)

        // app.logger.info("Created user with id: \(user.id?.uuidString ?? "nil")")

        // let existingUserId = UUID(uuidString: "b665d2a-d187-4ad9-95a9-c9fba82fee58")!

        // let game = Game(
        //     state: .lobby,
        //     hostID: existingUserId
        // )

        // try await game.save(on: app.db)

        // print("Game ID:", game.id!)

        do {
            let guess = Guess(
                userId: UUID(uuidString: "eb665d2a-d187-4ad9-95a9-c9fba82fee58")!,
                roundId: UUID(uuidString: "61ca795f-7e3c-442e-aade-2ea390677f8b")!,
                latitude: latitude,
                longitude: longitude,
                viewingDeadline: Date(),
                guessDeadline: Date()
            )

            try await guess.save(on: app.db)

        } catch {
            app.logger.error("Failed to save guess: \(error)")
            throw error
        }

        
        // 3. How to create the return object (Guess schema)
        // Look at your YAML: components -> schemas -> Guess.
        // The generator names this: Components.Schemas.Guess
        let dummyGuessResponse = Components.Schemas.Guess(
            id: UUID().uuidString,  // Matches type: string, format: uuid
            playerId: UUID().uuidString,  // Matches type: string, format: uuid
            lat: 1.11111,  // Echoing back the sent latitude
            lng: longitude,  // Echoing back the sent longitude
            submittedAt: Date()  // Matches type: string, format: date-time
        )

        // 4. Return the 201 Created response containing our dummy object
        return .created(.init(body: .json(dummyGuessResponse)))
    }

    func getGuesses(_ input: Operations.getGuesses.Input) async throws
        -> Operations.getGuesses.Output
    {
        .undocumented(statusCode: 501, .init())
    }
}
