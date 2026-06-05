import OpenAPIRuntime
import JWT
import Vapor
import Foundation


extension APIHandler {

    //input eq req object
    func register(_ input: Operations.register.Input) async throws -> Operations.register.Output {

        var id: UUID
        var username = input.username
        var password = input.password
        var user: User
        //check if username & password are valid
        if(true) {
            password = try input.password.hash(password)
            try {
                //create user in database
            } catch {
                Abort(409)
            }
        } else {
            Abort(400)
        }

        let user = //get user from database

        let payload = AuthPayload(
            subject: user.id
            expiration: getDate()
            username: user.username
        )
        
        return try await ["token": input.jwt.sign(payload)]
    }

    // Content Structs for return needed? mby Operations.login.Output??
    func login(_ input: Operations.login.Input) async throws -> Operations.login.Output {
        //check if username and password are correct
        let passwordHash = //get passwordHash from Database for username
        let correct = try input.password.verify(input.password, passwordHash)
        if(correct) {
            let user = // get User from Database
            let payload = AuthPayload(
            subject: user.id
            expiration: getDate()
            username: user.username
            )
        
            return try await ["token": input.jwt.sign(payload)]
        } else {
            Abort(401)
        }
    }

    func logout(_ input: Operations.logout.Input) async throws -> Operations.logout.Output {

        //jwt cant be revoke in a proper logout way... need to think of alternative or revise auth method
        .undocumented(statusCode: 501, .init())
    }
}

struct AuthPayload: JWTPayload {
    // Maps the longer Swift property names to the
    // shortened keys used in the JWT payload.
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case username = "usr"
    }

    var subject: SubjectClaim
    
    var expiration: ExpirationClaim

    var username: String
    
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}

func getDate() -> Date? {

    var dc = DateComponents()
    dc.year = 2030
    dc.month = 1
    dc.day = 1
    dc.timeZone = TimeZone(abbreviation: "CET")
    dc.hour = 1
    dc.minute = 1

    let userCalender = Calendar(identifier: .gregorian)
    let date = userCalender.date(from: dc)

    return date
}

