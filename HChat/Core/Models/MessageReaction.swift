//
//  MessageReaction.swift
//  HChat
//
//  Created on 2025-10-21.
//  消息表情反应模型

import Foundation

/// 消息表情反应
struct MessageReaction: Identifiable, Codable, Hashable {
    let id: String              // 反应ID
    let emoji: String           // 表情符号（如 👍、❤️、😂）
    let userId: String          // 反应用户的昵称
    let timestamp: Date         // 反应时间
    
    init(id: String = UUID().uuidString, emoji: String, userId: String, timestamp: Date = Date()) {
        self.id = id
        self.emoji = emoji
        self.userId = userId
        self.timestamp = timestamp
    }
}

/// 快捷反应表情列表
struct QuickReactions {
    static let defaults: [String] = ["👍", "❤️", "😂", "😮", "😢", "🎉"]
    
    /// 所有可用表情（扩展列表）
    static let all: [String] = [
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
struct ReactionSummary {
    let emoji: String
    var users: [String]         // 反应的用户列表
    var count: Int { users.count }
    
    /// 判断某个用户是否已反应
    func contains(user: String) -> Bool {
        users.contains(user)
    }
    
    /// 添加用户
    mutating func addUser(_ user: String) {
        if !users.contains(user) {
            users.append(user)
        }
    }
    
    /// 移除用户
    mutating func removeUser(_ user: String) {
        users.removeAll { $0 == user }
    }
}

