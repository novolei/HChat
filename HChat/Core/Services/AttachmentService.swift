import Foundation
import UIKit

/// 上传加密模式
enum AttachmentEncryptionMode {
    case none
    case e2ee(passphrase: String) // 使用群口令/私聊口令
}

/// 统一的附件上传服务
final class AttachmentService {

    private let minio: MinIOService
    private let uploader: UploadManager

    init(minio: MinIOService = Services.minio,
         uploader: UploadManager = Services.uploader) {
        self.minio = minio
        self.uploader = uploader
    }

    // MARK: - 对外入口

    /// 上传图片（UIImage），可选 E2EE
    @discardableResult
    func uploadImage(_ image: UIImage,
                     filename: String = "image.png",
                     toPrefix objectKeyPrefix: String = "rooms/ios-dev",
                     mode: AttachmentEncryptionMode = .none) async throws -> Attachment {
        guard let data = image.pngData() else {
            throw URLError(.cannotDecodeContentData)
        }
        switch mode {
        case .none:
            return try await putDataAsPublicAttachment(
                data, filename: filename, contentType: "image/png", objectKeyPrefix: objectKeyPrefix
            )
        case .e2ee(let passphrase):
            return try await uploader.encryptAndUploadFile(
                fileURL: data.writeToTemp(named: filename),
                filename: filename,
                originalContentType: "image/png",
                passphrase: passphrase,
                objectKeyPrefix: objectKeyPrefix
            )
        }
    }

    /// 上传任意二进制文件（Data），可选 E2EE
    @discardableResult
    func uploadFileData(_ data: Data,
                        filename: String,
                        contentType: String,
                        toPrefix objectKeyPrefix: String = "rooms/ios-dev",
                        mode: AttachmentEncryptionMode = .none) async throws -> Attachment {
        switch mode {
        case .none:
            return try await putDataAsPublicAttachment(
                data, filename: filename, contentType: contentType, objectKeyPrefix: objectKeyPrefix
            )
        case .e2ee(let passphrase):
            return try await uploader.encryptAndUploadFile(
                fileURL: data.writeToTemp(named: filename),
                filename: filename,
                originalContentType: contentType,
                passphrase: passphrase,
                objectKeyPrefix: objectKeyPrefix
            )
        }
    }

    /// 上传本地文件（URL），可选 E2EE
    @discardableResult
    func uploadFileURL(_ fileURL: URL,
                       filename: String? = nil,
                       contentType: String = "application/octet-stream",
                       toPrefix objectKeyPrefix: String = "rooms/ios-dev",
                       mode: AttachmentEncryptionMode = .none) async throws -> Attachment {
        let name = filename ?? fileURL.lastPathComponent
        switch mode {
        case .none:
            let data = try Data(contentsOf: fileURL)
            return try await putDataAsPublicAttachment(
                data, filename: name, contentType: contentType, objectKeyPrefix: objectKeyPrefix
            )
        case .e2ee(let passphrase):
            return try await uploader.encryptAndUploadFile(
                fileURL: fileURL,
                filename: name,
                originalContentType: contentType,
                passphrase: passphrase,
                objectKeyPrefix: objectKeyPrefix
            )
        }
    }

    // MARK: - 明文直传（保持和 MinIOService / Attachment 模型一致）

    private func putDataAsPublicAttachment(_ data: Data,
                                           filename: String,
                                           contentType: String,
                                           objectKeyPrefix: String) async throws -> Attachment {
        let dateFolder = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let objectKey = "\(objectKeyPrefix)/\(dateFolder)/\(UUID().uuidString)-\(filename)"

        // 1) 预签名
        let presign = try await minio.presign(objectKey: objectKey, contentType: contentType)
        // 2) 上传（注意这里需要 URL，而不是 String）
        try await minio.upload(putUrl: presign.putUrl, data: data, contentType: contentType)
        // 3) 返回统一的模型（Attachment.getUrl 是 URL?，不是 String）
        return Attachment(
            kind: kindFrom(contentType: contentType),
            filename: filename,
            contentType: contentType,
            putUrl: nil,
            getUrl: presign.getUrl,
            sizeBytes: Int64(data.count)
        )
    }

    private func kindFrom(contentType: String) -> Attachment.Kind {
        if contentType.hasPrefix("image/") { return .image }
        if contentType.hasPrefix("video/") { return .video }
        if contentType.hasPrefix("audio/") { return .audio }
        return .file
    }
}

// MARK: - 小工具：把 Data 写入临时文件
private extension Data {
    func writeToTemp(named: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(named)")
        try? self.write(to: url, options: .atomic)
        return url
    }
}
