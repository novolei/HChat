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
    public var duration: Double?    // 音频时长（秒）
    public var waveform: [CGFloat]? // 音频波形数据

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
        self.duration = nil
        self.waveform = nil
    }
}

/// 聊天消息模型
/// 
/// 核心功能：
/// - 基础消息属性（ID、频道、发送者、内容、时间戳）
/// - 附件支持（图片、视频、音频、文件）
/// - 表情反应系统（支持多用户对同一消息添加不同表情）
/// - 消息回复/引用
/// - 已读回执追踪
/// - 消息状态管理（发送中、已发送、失败、重试）
///
/// 性能优化：
/// - `reactionSummaries` 使用惰性计算减少内存开销
/// - 实现 `Hashable` 和 `Equatable` 用于高效比较
public struct ChatMessage: Identifiable, Hashable, Codable {
    public let id: String                  // 消息唯一标识
    public let channel: String             // 所属频道
    public let sender: String              // 发送者昵称
    public let text: String                // 消息文本内容
    public let timestamp: Date             // 发送时间
    public let attachments: [Attachment]   // 附件列表
    public let isLocalEcho: Bool           // 是否为本地回显（未确认发送成功）
    
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
    /// 性能优化：立即计算但使用高效的 Set 去重
    public var reactionSummaries: [ReactionSummary] {
        reactions.map { emoji, reactionList in
            // 使用 Set 去重，然后转换为数组（比 lazy 更可靠）
            let uniqueUsers = Array(Set(reactionList.map(\.userId)))
            return ReactionSummary(emoji: emoji, users: uniqueUsers)
        }.sorted { $0.count > $1.count }
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
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, channel, sender, text, timestamp, attachments, isLocalEcho
        case status, retryCount, reactions, replyTo, readReceipts
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.channel == rhs.channel &&
        lhs.sender == rhs.sender &&
        lhs.text == rhs.text &&
        lhs.timestamp == rhs.timestamp &&
        lhs.attachments == rhs.attachments &&
        lhs.isLocalEcho == rhs.isLocalEcho &&
        lhs.status == rhs.status &&
        lhs.retryCount == rhs.retryCount &&
        lhs.reactions == rhs.reactions &&
        lhs.replyTo == rhs.replyTo &&
        lhs.readReceipts == rhs.readReceipts
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(channel)
        hasher.combine(sender)
        hasher.combine(text)
        hasher.combine(timestamp)
        hasher.combine(attachments)
        hasher.combine(isLocalEcho)
        hasher.combine(status)
        hasher.combine(retryCount)
        hasher.combine(reactions)
        hasher.combine(replyTo)
        hasher.combine(readReceipts)
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
