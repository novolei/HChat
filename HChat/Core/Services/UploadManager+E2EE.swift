//
//  UploadManager+E2EE.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation
import CryptoKit

extension UploadManager {

    // MARK: - 公共接口（对外）
    /// 加密上传（把本地 fileURL 加密后直传 MinIO，返回可展示的 Attachment）
    func encryptAndUploadFile(
        fileURL: URL,
        filename: String,
        originalContentType: String,
        passphrase: String,
        objectKeyPrefix: String = "rooms/ios-dev"
    ) async throws -> Attachment {
        // 1) 生成加密临时文件（写头 + 写每个密文块）
        let encTmp = try await Self.encryptFileToTemp(
            fileURL: fileURL,
            passphrase: passphrase,
            chunkSize: 256 * 1024 // 256 KiB
        )

        // 2) 用 .hcss 扩展名存到对象存储（明确“加密载荷”）
        let dateFolder = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let objectKey = "\(objectKeyPrefix)/\(dateFolder)/\(UUID().uuidString)-\(filename).hcss"

        // 3) 请求预签名并上传（Content-Type 用自定义类型）
        let presign = try await minio.presign(objectKey: objectKey, contentType: "application/hcss+binary")
        let fileSize = try FileManager.default.attributesOfItem(atPath: encTmp.path)[.size] as? NSNumber
        try await UploadManager.uploadFileFromDisk(putUrl: presign.putUrl, fileURL: encTmp, contentType: "application/hcss+binary", contentLength: fileSize?.intValue)

        // 4) 返回"加密文件"的 Attachment（注意：展示/下载使用 getUrl）
        // 根据原始 contentType 判断附件类型
        let kind: Attachment.Kind
        if originalContentType.hasPrefix("image/") {
            kind = .image
        } else if originalContentType.hasPrefix("video/") {
            kind = .video
        } else if originalContentType.hasPrefix("audio/") {
            kind = .audio
        } else {
            kind = .file
        }
        
        return Attachment(kind: kind,
                          filename: filename + ".hcss",
                          contentType: "application/hcss+binary",
                          putUrl: nil,
                          getUrl: presign.getUrl,
                          sizeBytes: fileSize?.int64Value)
    }

    /// 下载并解密到本地临时文件，返回“解密后的临时URL”（你可用 QuickLook/分享打开）
    static func downloadAndDecryptToTemp(
        from encryptedURL: URL,
        passphrase: String
    ) async throws -> URL {
        // 1) 下载到临时
        let (tmpFile, _) = try await URLSession.shared.download(from: encryptedURL)
        // 2) 解密 -> 临时明文文件
        return try decryptFileToTemp(encryptedFileURL: tmpFile, passphrase: passphrase)
    }
}

// MARK: - SecretStream 实现细节（头、加解密）
private struct SecretHeader: Codable {
    let version: Int            // 1
    let alg: String             // "ChaChaPoly-HKDF-SHA256"
    let info: String            // "hc-secretstream-v1"
    let hkdfSalt_b64: String    // 16 bytes salt
    let noncePrefix_b64: String // 8 bytes
    let chunkSize: Int
    let fileSize: Int64
    let chunkCount: Int
}

private enum SecretStreamError: Error {
    case badHeader
    case badNonce
    case decryptionFailed
    case io(String)
}

private extension UploadManager {

    // MARK: - Encrypt (fileURL -> encryptedTempFile)
    static func encryptFileToTemp(
        fileURL: URL,
        passphrase: String,
        chunkSize: Int
    ) async throws -> URL {
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let chunkCount = Int((fileSize + Int64(chunkSize) - 1) / Int64(chunkSize))

        // KDF materials
        let salt = randomBytes(count: 16)
        let noncePrefix = randomBytes(count: 8)

        let key = try deriveKeyHKDF(passphrase: passphrase, salt: salt, info: "hc-secretstream-v1")

        // Header（JSON + 前置4字节长度）
        let header = SecretHeader(
            version: 1,
            alg: "ChaChaPoly-HKDF-SHA256",
            info: "hc-secretstream-v1",
            hkdfSalt_b64: Data(salt).base64EncodedString(),
            noncePrefix_b64: Data(noncePrefix).base64EncodedString(),
            chunkSize: chunkSize,
            fileSize: fileSize,
            chunkCount: chunkCount
        )
        let headerJSON = try JSONEncoder().encode(header)
        var headerBlob = Data()
        headerBlob.append(UInt32(headerJSON.count).bigEndianData)
        headerBlob.append(headerJSON)

        // Prepare IO
        let encTmp = FileManager.default.temporaryDirectory.appendingPathComponent("enc-\(UUID().uuidString).hcss")
        FileManager.default.createFile(atPath: encTmp.path, contents: nil)
        guard let out = try? FileHandle(forWritingTo: encTmp),
              let `in` = try? FileHandle(forReadingFrom: fileURL) else {
            throw SecretStreamError.io("open file handles")
        }
        defer { try? out.close(); try? `in`.close() }

        // 写入头
        try out.write(contentsOf: headerBlob)

        // 分块加密并写入
        var remaining = Int64(fileSize)
        var index = 0
        while remaining > 0 {
            let readLen = Int(min(Int64(chunkSize), remaining))
            let plain = try `in`.readExactly(count: readLen)
            let aad = aadFor(index: index)
            let nonce = try nonceFrom(prefix: noncePrefix, index: index)

            // CryptoKit：seal -> combined = nonce(12) + ciphertext + tag(16)
            let sealed = try ChaChaPoly.seal(plain, using: key, nonce: nonce, authenticating: aad)
            let combined = sealed.combined
            // 我们只写入 [ciphertext + tag]，nonce 用我们自定义的可复现序列
            let ctPlusTag = combined.dropFirst(12)
            try out.write(contentsOf: ctPlusTag)

            remaining -= Int64(readLen)
            index += 1
        }

        return encTmp
    }

    // MARK: - Decrypt (encryptedFileURL -> decryptedTempFile)
    static func decryptFileToTemp(
        encryptedFileURL: URL,
        passphrase: String
    ) throws -> URL {
        guard let `in` = try? FileHandle(forReadingFrom: encryptedFileURL) else {
            throw SecretStreamError.io("open encrypted for read")
        }
        defer { try? `in`.close() }

        // 读头长度 + 头
        let lenData = try `in`.readExactly(count: 4)
        let headerLen = Int(UInt32(bigEndianBytes: lenData))
        let headerJSON = try `in`.readExactly(count: headerLen)
        let header = try JSONDecoder().decode(SecretHeader.self, from: headerJSON)

        guard header.version == 1, header.alg == "ChaChaPoly-HKDF-SHA256" else {
            throw SecretStreamError.badHeader
        }

        let salt = Data(base64Encoded: header.hkdfSalt_b64) ?? Data()
        let noncePrefix = Data(base64Encoded: header.noncePrefix_b64) ?? Data()
        guard salt.count == 16, noncePrefix.count == 8 else { throw SecretStreamError.badHeader }

        let key = try deriveKeyHKDF(passphrase: passphrase, salt: Array(salt), info: header.info)

        // 输出临时明文文件
        let decTmp = FileManager.default.temporaryDirectory.appendingPathComponent("dec-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: decTmp.path, contents: nil)
        guard let out = try? FileHandle(forWritingTo: decTmp) else {
            throw SecretStreamError.io("open dec for write")
        }
        defer { try? out.close() }

        // 逐块解密
        var remaining: Int64 = header.fileSize
        for index in 0 ..< header.chunkCount {
            let plainLen = Int(min(Int64(header.chunkSize), remaining))
            let ctPlusTagLen = plainLen + 16 // ChaChaPoly tag
            let ctPlusTag = try `in`.readExactly(count: ctPlusTagLen)

            // 还原 sealedBox：拆 tag
            let ciphertext = ctPlusTag.dropLast(16)
            let tag = ctPlusTag.suffix(16)
            let nonce = try nonceFrom(prefix: Array(noncePrefix), index: index)
            let aad = aadFor(index: index)
            
            let sealed = try ChaChaPoly.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: Data(tag))

//            let sealed = try ChaChaPoly.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: ChaChaPoly.Tag(tag))
            do {
                let plaintext = try ChaChaPoly.open(sealed, using: key, authenticating: aad)
                try out.write(contentsOf: plaintext)
            } catch {
                throw SecretStreamError.decryptionFailed
            }

            remaining -= Int64(plainLen)
        }

        return decTmp
    }

    // MARK: - Helpers

    static func deriveKeyHKDF(passphrase: String, salt: [UInt8], info: String) throws -> SymmetricKey {
        // 用 SHA256(passphrase) 作为 IKM 再做 HKDF，更抗弱口令
        let ikm = SHA256.hash(data: Data(passphrase.utf8))
        let inputKey = SymmetricKey(data: Data(ikm))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: Data(salt),
            info: Data(info.utf8),
            outputByteCount: 32
        )
    }

    static func randomBytes(count: Int) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &b)
        return b
    }

    static func nonceFrom(prefix: [UInt8], index: Int) throws -> ChaChaPoly.Nonce {
        guard prefix.count == 8 else { throw SecretStreamError.badNonce }
        var nonce = Data(prefix)
        var be = UInt32(index).bigEndian
        withUnsafeBytes(of: &be) { nonce.append(contentsOf: $0) } // 8 + 4 = 12 bytes
        return try ChaChaPoly.Nonce(data: nonce)
    }

    static func aadFor(index: Int) -> Data {
        var d = Data("HCSSv1".utf8)
        var be = UInt32(index).bigEndian
        withUnsafeBytes(of: &be) { d.append(contentsOf: $0) }
        return d
    }

    static func uploadFileFromDisk(putUrl: URL, fileURL: URL, contentType: String, contentLength: Int?) async throws {
        var req = URLRequest(url: putUrl)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let len = contentLength { req.setValue("\(len)", forHTTPHeaderField: "Content-Length") }
        let (_, resp) = try await URLSession.shared.upload(for: req, fromFile: fileURL)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.cannotCreateFile)
        }
    }
}

// MARK: - FileHandle 小工具
private extension FileHandle {
    func readExactly(count: Int) throws -> Data {
        var data = Data()
        data.reserveCapacity(count)
        while data.count < count {
            let chunk = try self.read(upToCount: count - data.count) ?? Data()
            if chunk.isEmpty { throw SecretStreamError.io("unexpected EOF") }
            data.append(chunk)
        }
        return data
    }
}

private extension UInt32 {
    var bigEndianData: Data {
        var be = self.bigEndian
        return Data(bytes: &be, count: MemoryLayout<UInt32>.size)
    }
    init(bigEndianBytes: Data) {
        self = bigEndianBytes.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
    }
}
