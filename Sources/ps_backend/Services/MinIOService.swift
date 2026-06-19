import Vapor
import SotoS3
import SotoCore
import AsyncHTTPClient

struct MinIOService {
    let s3: S3
    let bucket: String
    let client: AWSClient

    init() {
        let endpoint = Environment.get("MINIO_ENDPOINT") ?? "http://minio:9000"
        let user = Environment.get("MINIO_USER") ?? "minioadmin"
        let secret = Environment.get("MINIO_SECRET") ?? "minioadmin"
        self.bucket = Environment.get("MINIO_BUCKET") ?? "photos"

        self.client = AWSClient(
            credentialProvider: .static(
                accessKeyId: user,
                secretAccessKey: secret
            ),
            httpClientProvider: .createNew
        )

        self.s3 = S3(
            client: client,
            region: .useast1,
            endpoint: endpoint
        )
    }

    func upload(data: Data, key: String) async throws -> String {
        let request = S3.PutObjectRequest(
            body: .data(data),
            bucket: bucket,
            key: key
        )
        _ = try await s3.putObject(request)
        let endpoint = Environment.get("MINIO_ENDPOINT") ?? "http://minio:9000"
        return "\(endpoint)/\(bucket)/\(key)"
    }

    func delete(key: String) async throws {
        let request = S3.DeleteObjectRequest(
            bucket: bucket,
            key: key
        )
        _ = try await s3.deleteObject(request)
    }

    

    func shutdown() throws {
        try client.syncShutdown()
    }
}