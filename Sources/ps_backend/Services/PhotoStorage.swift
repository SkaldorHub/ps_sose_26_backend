import Vapor
import SotoS3

struct PhotoStorage {
    let s3: S3
    let bucket: String

    /// Idempotent: legt den Bucket an, falls er noch nicht existiert (MinIO erstellt ihn nicht automatisch).
    func ensureBucketExists() async throws {
        do {
            _ = try await s3.headBucket(.init(bucket: bucket))
        } catch {
            _ = try await s3.createBucket(.init(bucket: bucket))
        }
    }

    func upload(data: [UInt8], key: String, contentType: String) async throws -> String {
        _ = try await s3.putObject(.init(
            body: .init(bytes: data),
            bucket: bucket,
            contentType: contentType,
            key: key
        ))
        return key
    }

    func download(key: String) async throws -> ByteBuffer {
        let output = try await s3.getObject(.init(bucket: bucket, key: key))
        return try await output.body.collect(upTo: 20 * 1024 * 1024)
    }
}

extension Application {
    private struct PhotoStorageKey: StorageKey { typealias Value = PhotoStorage }

    var photoStorage: PhotoStorage {
        get { storage[PhotoStorageKey.self]! }
        set { storage[PhotoStorageKey.self] = newValue }
    }
}

struct AWSClientLifecycleHandler: LifecycleHandler {
    let client: AWSClient

    func shutdownAsync(_ app: Application) async throws {
        try await client.shutdown()
    }
}
