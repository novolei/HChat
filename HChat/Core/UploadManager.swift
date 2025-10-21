//
//  UploadManager.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation
import PhotosUI
import AVFoundation
import UIKit

final class UploadManager {
    enum UploadError: Error { case cannotLoad, presignFailed, uploadFailed }
    let minio: MinIOService

    init(minio: MinIOService) { self.minio = minio }

    func prepareImageAttachment(_ data: Data, filename: String) async throws -> Attachment {
        let key = "rooms/ios-dev/\(Date().formatted(date: .abbreviated, time: .omitted))/\(UUID().uuidString)-\(filename)"
        let presign = try await minio.presign(objectKey: key, contentType: "image/png")
        try await minio.upload(putUrl: presign.putUrl, data: data, contentType: "image/png")
        return Attachment(kind: .image, filename: filename, contentType: "image/png",
                          putUrl: nil, getUrl: presign.getUrl, sizeBytes: Int64(data.count))
    }

    func prepareFileAttachment(_ data: Data, filename: String, contentType: String) async throws -> Attachment {
        let key = "rooms/ios-dev/\(Date().formatted(date: .abbreviated, time: .omitted))/\(filename)"
        let presign = try await minio.presign(objectKey: key, contentType: contentType)
        try await minio.upload(putUrl: presign.putUrl, data: data, contentType: contentType)
        return Attachment(kind: .file, filename: filename, contentType: contentType,
                          putUrl: nil, getUrl: presign.getUrl, sizeBytes: Int64(data.count))
    }
}
