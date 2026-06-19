import Vapor
import OpenAPIVapor

func routes(_ app: Application) throws {
    let transport = VaporTransport(routesBuilder: app.grouped(AuthMiddleware()))
    try APIHandler(app: app).registerHandlers(on: transport)
}