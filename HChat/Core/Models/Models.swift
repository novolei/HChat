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

public struct ChatMessage: Identifiable, Hashable, Codable {
    public let id: String
    public let channel: String
    public let sender: String
    public let text: String
    public let timestamp: Date
    public let attachments: [Attachment]
    public let isLocalEcho: Bool
    
    // ✨ P0: 消息可靠性
    public var status: MessageStatus = .sent        // 消息状态
    public var retryCount: Int = 0                   // 重试次数
    
    // ✨ P1: 表情回应
    public var reactions: [String: [MessageReaction]] = [:]  // emoji -> reactions
    
    // ✨ P1: 消息引用/回复
    public var replyTo: MessageReply?                // 引用的消息
    
    // ✨ P1: 已读回执
    public var readReceipts: [ReadReceipt] = []      // 已读回执列表

    public init(id: String = UUID().uuidString,
                channel: String, sender: String, text: String,
                timestamp: Date = .init(),
                attachments: [Attachment] = [],
                isLocalEcho: Bool = false,
                status: MessageStatus = .sent,
                retryCount: Int = 0,
                reactions: [String: [MessageReaction]] = [:],
                replyTo: MessageReply? = nil,
                readReceipts: [ReadReceipt] = []) {
        self.id = id
        self.channel = channel
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.attachments = attachments
        self.isLocalEcho = isLocalEcho
        self.status = status
        self.retryCount = retryCount
        self.reactions = reactions
        self.replyTo = replyTo
        self.readReceipts = readReceipts
    }
    
    // MARK: - 辅助方法
    
    /// 是否有表情反应
    public var hasReactions: Bool {
        !reactions.isEmpty
    }
    
    /// 总反应数
    public var totalReactionCount: Int {
        reactions.values.reduce(0) { $0 + $1.count }
    }
    
    /// 获取反应摘要（按表情分组）
    public var reactionSummaries: [ReactionSummary] {
        reactions.map { emoji, reactionList in
            ReactionSummary(emoji: emoji, users: reactionList.map(\.userId))
        }.sorted { $0.count > $1.count }  // 按反应数量降序
    }
    
    /// 是否是回复消息
    public var isReply: Bool {
        replyTo != nil
    }
    
    /// 是否有已读回执
    public var hasReadReceipts: Bool {
        !readReceipts.isEmpty
    }
    
    /// 已读人数
    public var readCount: Int {
        readReceipts.count
    }
    
    /// 检查某人是否已读
    public func isReadBy(_ userId: String) -> Bool {
        readReceipts.contains { $0.userId == userId }
    }
    
    /// 已读用户列表
    public var readByUsers: [String] {
        readReceipts.map(\.userId)
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
