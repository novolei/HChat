//
//  MessageReaction.swift
//  HChat
//
//  Created on 2025-10-21.
//  消息表情反应模型

import Foundation

/// 消息表情反应
public struct MessageReaction: Identifiable, Codable, Hashable {
    public let id: String              // 反应ID
    public let emoji: String           // 表情符号（如 👍、❤️、😂）
    public let userId: String          // 反应用户的昵称
    public let timestamp: Date         // 反应时间
    
    public init(id: String = UUID().uuidString, emoji: String, userId: String, timestamp: Date = Date()) {
        self.id = id
        self.emoji = emoji
        self.userId = userId
        self.timestamp = timestamp
    }
}

/// 快捷反应表情列表
public struct QuickReactions {
    public static let defaults: [String] = ["👍", "❤️", "😂", "😮", "😢", "🎉"]
    
    /// 所有可用表情（扩展列表）
    public static let all: [String] = [
        // 赞同
        "👍", "👏", "💪", "🙌", "✨",
        // 情感
        "❤️", "😍", "🥰", "😘", "💕",
        // 开心
        "😂", "🤣", "😆", "😄", "🎉",
        // 惊讶
        "😮", "😲", "🤯", "👀", "🔥",
        // 伤心
        "😢", "😭", "💔", "😔", "🙏",
        // 其他
        "🎯", "⭐", "✅", "❌", "🚀"
    ]
}

/// 反应统计（按表情分组）
public struct ReactionSummary {
    public let emoji: String
    public var users: [String]         // 反应的用户列表
    public var count: Int { users.count }
    
    public init(emoji: String, users: [String]) {
        self.emoji = emoji
        self.users = users
    }
    
    /// 判断某个用户是否已反应
    public func contains(user: String) -> Bool {
        users.contains(user)
    }
    
    /// 添加用户
    public mutating func addUser(_ user: String) {
        if !users.contains(user) {
            users.append(user)
        }
    }
    
    /// 移除用户
    public mutating func removeUser(_ user: String) {
        users.removeAll { $0 == user }
    }
}

