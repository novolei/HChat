//
//  Conversation.swift
//  HChat
//
//  Created on 2025-10-23.
//  会话模型 - 统一管理私聊和频道
//

import Foundation

/// 会话类型
public enum ConversationType: String, Codable {
    case dm          // 私聊（Direct Message）
    case channel     // 频道
    case group       // 群聊（未来扩展）
}

/// 聊天会话
/// 
/// 用于统一管理私聊、频道、群聊等不同类型的会话
/// 包含最后消息、未读数、置顶等状态
public struct Conversation: Identifiable, Codable, Equatable {
    public let id: String                  // 会话 ID
    public let type: ConversationType      // 会话类型
    public var title: String               // 显示名称
    public var avatar: String?             // 头像 URL
    public var lastMessage: ChatMessage?   // 最后一条消息
    public var unreadCount: Int = 0        // 未读消息数
    public var isPinned: Bool = false      // 是否置顶
    public var isMuted: Bool = false       // 是否免打扰
    public var updatedAt: Date             // 最后更新时间
    
    // 私聊专属字段
    public var otherUserId: String?        // 对方用户 ID（私聊）
    public var isOnline: Bool = false      // 对方是否在线（私聊）
    
    // 频道专属字段
    public var channelId: String?          // 频道 ID
    public var memberCount: Int = 0        // 成员数
    
    public init(
        id: String,
        type: ConversationType,
        title: String,
        avatar: String? = nil,
        lastMessage: ChatMessage? = nil,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        updatedAt: Date = Date(),
        otherUserId: String? = nil,
        isOnline: Bool = false,
        channelId: String? = nil,
        memberCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.avatar = avatar
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.updatedAt = updatedAt
        self.otherUserId = otherUserId
        self.isOnline = isOnline
        self.channelId = channelId
        self.memberCount = memberCount
    }
}

/// 用户在线状态信息
public struct OnlineStatus: Codable, Equatable {
    public let userId: String              // 用户 ID
    public var isOnline: Bool              // 是否在线
    public var lastSeen: Date?             // 最后在线时间
    public var customStatus: String?       // 自定义状态（"忙碌"、"学习中"等）
    
    public init(
        userId: String,
        isOnline: Bool = false,
        lastSeen: Date? = nil,
        customStatus: String? = nil
    ) {
        self.userId = userId
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.customStatus = customStatus
    }
}

