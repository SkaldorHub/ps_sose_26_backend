import OpenAPIRuntime
import Foundation

extension APIHandler {

    func getCurrentRound(_ input: Operations.getCurrentRound.Input) async throws -> Operations.getCurrentRound.Output {
        .undocumented(statusCode: 501, .init())
    }

    func uploadPhoto(_ input: Operations.uploadPhoto.Input) async throws -> Operations.uploadPhoto.Output {
        let minioService = MinIOService()
        
        guard case .multipartForm(let multipart) = input.body else {
            return .undocumented(statusCode: 400, .init())
        }
        
        for try await part in multipart {
            if case .photo(let photoPart) = part {
                let body = photoPart.payload.body
                let bytes = try await [UInt8](collecting: body, upTo: 10 * 1024 * 1024)
                let key = "\(input.path.gameId)/\(Foundation.UUID().uuidString).jpg"
                _ = try await minioService.upload(data: Foundation.Data(bytes), key: key)
                return .created(.init())
            }
        }
        
        return .undocumented(statusCode: 400, .init())
    }

    func replacePhoto(_ input: Operations.replacePhoto.Input) async throws -> Operations.replacePhoto.Output {
        .undocumented(statusCode: 501, .init())
    }

    func deletePhoto(_ input: Operations.deletePhoto.Input) async throws -> Operations.deletePhoto.Output {
        .undocumented(statusCode: 501, .init())
    }

    func getUploadStatus(_ input: Operations.getUploadStatus.Input) async throws -> Operations.getUploadStatus.Output {
        .undocumented(statusCode: 501, .init())
    }
}