//
//  ReactionManager.swift
//  HChat
//
//  Created on 2025-10-21.
//  表情反应管理器
//
//  核心功能：
//  - 管理消息的表情反应（添加、删除、切换）
//  - 单用户单表情规则：同一用户只能对一条消息保留一个表情
//  - 本地状态更新 + 服务器同步
//  - 处理服务器推送的表情事件
//
//  使用示例：
//  ```swift
//  reactionManager.toggleReaction(
//      emoji: "👍",
//      messageId: "msg-123",
//      channel: "general"
//  )
//  ```

import Foundation
import Observation

@MainActor
@Observable
final class ReactionManager {
    // MARK: - 依赖
    private weak var client: HackChatClient?
    private weak var state: ChatState?
    
    // MARK: - 初始化
    
    init(client: HackChatClient? = nil, state: ChatState? = nil) {
        self.client = client
        self.state = state
    }
    
    /// 设置依赖（用于延迟注入）
    func setDependencies(client: HackChatClient, state: ChatState) {
        self.client = client
        self.state = state
    }
    
    // MARK: - 公开方法
    
    /// 添加反应
    func addReaction(emoji: String, to messageId: String, in channel: String) {
        guard let client = client, let state = state else { return }
        
        DebugLogger.log("👍 添加反应: \(emoji) -> 消息 \(messageId)", level: .debug)
        
        // 构建反应对象
        let reaction = MessageReaction(
            emoji: emoji,
            userId: state.myNick,
            timestamp: Date()
        )
        
        // 立即更新本地状态（乐观更新）
        upsertReaction(messageId: messageId, channel: channel, reaction: reaction)
        
        // 发送到服务器
        client.send(json: [
            "type": "add_reaction",
            "messageId": messageId,
            "channel": channel,
            "emoji": emoji,
            "reactionId": reaction.id,
            "timestamp": reaction.timestamp.timeIntervalSince1970
        ])
    }
    
    /// 移除反应
    func removeReaction(emoji: String, from messageId: String, in channel: String) {
        guard let client = client, let state = state else { return }
        
        DebugLogger.log("👎 移除反应: \(emoji) <- 消息 \(messageId)", level: .debug)
        
        // 立即更新本地状态（乐观更新）
        removeReactionLocally(messageId: messageId, channel: channel, emoji: emoji, userId: state.myNick)
        
        // 发送到服务器
        client.send(json: [
            "type": "remove_reaction",
            "messageId": messageId,
            "channel": channel,
            "emoji": emoji
        ])
    }
    
    /// 切换反应（如果已有则移除，否则添加）
    func toggleReaction(emoji: String, messageId: String, channel: String) {
        guard let state = state else { return }

        let userId = state.myNick

        // 检查用户当前的反应
        if let currentEmoji = currentReactionEmoji(messageId: messageId, channel: channel, userId: userId) {
            if currentEmoji == emoji {
                removeReaction(emoji: emoji, from: messageId, in: channel)
            } else {
                replaceReaction(from: currentEmoji, to: emoji, messageId: messageId, channel: channel, userId: userId)
            }
        } else {
            addReaction(emoji: emoji, to: messageId, in: channel)
        }
    }

    /// 获取用户当前对消息使用的表情
    func currentReactionEmoji(messageId: String, channel: String, userId: String) -> String? {
        guard let state = state,
              let messages = state.messagesByChannel[channel],
              let message = messages.first(where: { $0.id == messageId }) else {
            return nil
        }

        for (emoji, reactions) in message.reactions where reactions.contains(where: { $0.userId == userId }) {
            return emoji
        }
        return nil
    }
    
    /// 检查用户是否已对消息添加了某个表情反应
    func hasReaction(emoji: String, messageId: String, channel: String, userId: String) -> Bool {
        guard let state = state,
              var messages = state.messagesByChannel[channel],
              let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            return false
        }
        
        let reactions = messages[messageIndex].reactions[emoji] ?? []
        return reactions.contains { $0.userId == userId }
    }
    
    // MARK: - 接收处理
    
    /// 处理收到的反应添加通知
    func handleReactionAdded(_ data: [String: Any]) {
        guard let messageId = data["messageId"] as? String,
              let channel = data["channel"] as? String,
              let emoji = data["emoji"] as? String,
              let userId = data["userId"] as? String else {
            DebugLogger.log("⚠️ 反应添加数据不完整", level: .warning)
            return
        }
        
        let reactionId = (data["reactionId"] as? String) ?? UUID().uuidString
        let timestamp = (data["timestamp"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? Date()
        
        let reaction = MessageReaction(
            id: reactionId,
            emoji: emoji,
            userId: userId,
            timestamp: timestamp
        )
        
        DebugLogger.log("📥 收到反应添加: \(emoji) by \(userId) -> 消息 \(messageId)", level: .debug)
        
        // 更新本地状态
        upsertReaction(messageId: messageId, channel: channel, reaction: reaction)
    }
    
    /// 处理收到的反应移除通知
    func handleReactionRemoved(_ data: [String: Any]) {
        guard let messageId = data["messageId"] as? String,
              let channel = data["channel"] as? String,
              let emoji = data["emoji"] as? String,
              let userId = data["userId"] as? String else {
            DebugLogger.log("⚠️ 反应移除数据不完整", level: .warning)
            return
        }
        
        DebugLogger.log("📥 收到反应移除: \(emoji) by \(userId) <- 消息 \(messageId)", level: .debug)
        
        // 更新本地状态
        removeReactionLocally(messageId: messageId, channel: channel, emoji: emoji, userId: userId)
    }
    
    // MARK: - 私有方法
    
    /// 添加或替换本地反应
    private func upsertReaction(messageId: String, channel: String, reaction: MessageReaction) {
        guard let state = state,
              var messages = state.messagesByChannel[channel],
              let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        var message = messages[messageIndex]

        // 移除其它表情（单用户单表情规则）
        for key in Array(message.reactions.keys) where key != reaction.emoji {
            message.reactions[key]?.removeAll { $0.userId == reaction.userId }
            if message.reactions[key]?.isEmpty ?? false {
                message.reactions.removeValue(forKey: key)
            }
        }

        // 更新当前表情
        if message.reactions[reaction.emoji] == nil {
            message.reactions[reaction.emoji] = []
        }
        message.reactions[reaction.emoji]?.removeAll { $0.userId == reaction.userId }
        message.reactions[reaction.emoji]?.append(reaction)

        messages[messageIndex] = message
        state.messagesByChannel[channel] = messages
        
        DebugLogger.log("✅ 本地更新表情: \(reaction.emoji) for message \(messageId.prefix(8))", level: .debug)
    }

    /// 移除本地反应
    private func removeReactionLocally(messageId: String, channel: String, emoji: String, userId: String) {
        guard let state = state,
              var messages = state.messagesByChannel[channel],
              let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        var message = messages[messageIndex]

        message.reactions[emoji]?.removeAll { $0.userId == userId }
        if message.reactions[emoji]?.isEmpty ?? true {
            message.reactions.removeValue(forKey: emoji)
        }

        messages[messageIndex] = message
        state.messagesByChannel[channel] = messages
        
        DebugLogger.log("✅ 本地移除表情: \(emoji) for message \(messageId.prefix(8))", level: .debug)
    }

    /// 替换用户的表情反应
    private func replaceReaction(from oldEmoji: String, to newEmoji: String, messageId: String, channel: String, userId: String) {
        // 先移除旧表情
        removeReactionLocally(messageId: messageId, channel: channel, emoji: oldEmoji, userId: userId)
        client?.send(json: [
            "type": "remove_reaction",
            "messageId": messageId,
            "channel": channel,
            "emoji": oldEmoji
        ])

        // 再添加新表情（使用新的时间戳和 ID）
        let reaction = MessageReaction(emoji: newEmoji, userId: userId, timestamp: Date())
        upsertReaction(messageId: messageId, channel: channel, reaction: reaction)
        client?.send(json: [
            "type": "add_reaction",
            "messageId": messageId,
            "channel": channel,
            "emoji": newEmoji,
            "reactionId": reaction.id,
            "timestamp": reaction.timestamp.timeIntervalSince1970
        ])
    }

}

