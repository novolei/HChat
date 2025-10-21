//
//  Models.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation
import UniformTypeIdentifiers

public struct Attachment: Hashable, Codable, Identifiable {
    public enum Kind: String, Codable { case image, video, audio, file }
    public let id: String
    public let kind: Kind
    public let filename: String
    public let contentType: String
    public let putUrl: URL?      // 仅上传阶段用
    public let getUrl: URL?      // 展示/下载用（MinIO 预签名）
    public let sizeBytes: Int64?

    public init(id: String = UUID().uuidString,
                kind: Kind, filename: String, contentType: String,
                putUrl: URL?, getUrl: URL?, sizeBytes: Int64?) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.contentType = contentType
        self.putUrl = putUrl
        self.getUrl = getUrl
        self.sizeBytes = sizeBytes
    }
}

public struct ChatMessage: Identifiable, Hashable {
    public let id: String
    public let channel: String
    public let sender: String
    public let text: String
    public let timestamp: Date
    public let attachments: [Attachment]
    public let isLocalEcho: Bool

    public init(id: String = UUID().uuidString,
                channel: String, sender: String, text: String,
                timestamp: Date = .init(),
                attachments: [Attachment] = [],
                isLocalEcho: Bool = false) {
        self.id = id
        self.channel = channel
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.attachments = attachments
        self.isLocalEcho = isLocalEcho
    }
}

public struct Channel: Identifiable, Hashable {
    public let id: String
    public let name: String
    public var unreadCount: Int = 0
    public var lastMessageAt: Date? = nil
    public init(name: String) { self.id = name; self.name = name }
}

public struct PresignResponse: Codable {
    public let bucket: String
    public let objectKey: String
    public let putUrl: URL
    public let getUrl: URL
    public let expiresSeconds: Int
}

public enum ClientCommand: Equatable {
    case join(String)       // /join room
    case nick(String)       // /nick Name#secret
    case `me`(String)       // /me action
    case dm(String,String)   // /dm Alice hello
    case clear              // /clear
    case help               // /help
    case unknown(String)
}
