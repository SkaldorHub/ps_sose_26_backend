import Vapor
import OpenAPIVapor

func routes(_ app: Application) throws {
    let transport = VaporTransport(routesBuilder: app)
    try APIHandler(app: app).registerHandlers(on: transport)
}
