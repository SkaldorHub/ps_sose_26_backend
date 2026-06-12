import OpenAPIRuntime
import JWT
import Vapor
import Foundation
import Fluent


extension APIHandler {

    //input eq req object
    func register(_ input: Operations.register.Input) async throws -> Operations.register.Output {

        let id: UUID
        let username: String = input.body.
        let password: String = input.password
        let user: User
        let regex: String = "^([A-Za-z0-9])+$"
        let db: Database = req.db

        let valid = validate(text: username, with: regex) && validate(text: password, with: regex)

        //check if username & password are valid?
        
        if(valid) {
            password = try input.password.hash(password)
            do {
                user = User(username: username, passwordHash: password)
                user.create(on: db)
                id = user.id!
            } catch {
                throw Abort(/* db error mb rather internal? */)
            }
        } else {
            Abort(/* validation error */)
        }

        let payload = AuthPayload(
            subject: .init(value: id.description),
            expiration: .init(value: getDate()!),
            username: user.username
        )

        let token = try await req.jwt.sign(payload)
        
        return .created(.init(body: .json(.init(
            token: token,
            userId: id.description,
            username: username
        ))))
    }

    // Content Structs for return needed? mby Operations.login.Output??
    func login(_ input: Operations.login.Input) async throws -> Operations.login.Output {
        //check if username and password are correct
        let db: Database = req.db
        let username: String = input.username
        let password: String = input.password

        let user: User? = User.query(on: db).filter(\.$username == username).first()

        let correct = try req.password.verify(input.password, user!.passwordHash)

        if(correct) {

            let id = user!.id!
            let payload: AuthPayload = AuthPayload(
            subject: .init(value: id.description),
            expiration: .init(value: getDate()!),
            username: user!.username
            )

            let token = try await ["token": input.jwt.sign(payload)]
        
            return .ok(.init(body: .json(.init(
            token: token,
            userId: id.description,
            username: username
        ))))
        } else {
            Abort(/* Login error */)
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

func validate(text: String, with regex: String) -> Bool {
        // Create the regex
        guard let gRegex = try? NSRegularExpression(pattern: regex) else {
            return false
        }
        
        // Create the range
        let range = NSRange(location: 0, length: text.utf16.count)
        
        // Perform the test
        if gRegex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        
        return false
}

