//
//  ReactionManager.swift
//  HChat
//
//  Created on 2025-10-21.
//  表情反应管理器

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
        updateLocalReaction(messageId: messageId, channel: channel, reaction: reaction, isAdding: true)
        
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
        updateLocalReaction(messageId: messageId, channel: channel, emoji: emoji, userId: state.myNick, isRemoving: true)
        
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
        
        // 检查是否已有该反应
        if hasReaction(emoji: emoji, messageId: messageId, channel: channel, userId: state.myNick) {
            removeReaction(emoji: emoji, from: messageId, in: channel)
        } else {
            addReaction(emoji: emoji, to: messageId, in: channel)
        }
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
        updateLocalReaction(messageId: messageId, channel: channel, reaction: reaction, isAdding: true)
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
        updateLocalReaction(messageId: messageId, channel: channel, emoji: emoji, userId: userId, isRemoving: true)
    }
    
    // MARK: - 私有方法
    
    /// 更新本地反应状态（添加反应）
    private func updateLocalReaction(messageId: String, channel: String, reaction: MessageReaction, isAdding: Bool) {
        guard let state = state,
              var messages = state.messagesByChannel[channel],
              let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        var message = messages[messageIndex]
        
        if isAdding {
            // 添加反应
            if message.reactions[reaction.emoji] == nil {
                message.reactions[reaction.emoji] = []
            }
            
            // 避免重复添加
            if !message.reactions[reaction.emoji]!.contains(where: { $0.userId == reaction.userId }) {
                message.reactions[reaction.emoji]!.append(reaction)
            }
        }
        
        messages[messageIndex] = message
        state.messagesByChannel[channel] = messages
    }
    
    /// 更新本地反应状态（移除反应）
    private func updateLocalReaction(messageId: String, channel: String, emoji: String, userId: String, isRemoving: Bool) {
        guard let state = state,
              var messages = state.messagesByChannel[channel],
              let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        var message = messages[messageIndex]
        
        if isRemoving {
            // 移除反应
            message.reactions[emoji]?.removeAll { $0.userId == userId }
            
            // 如果该表情没有任何反应了，移除整个键
            if message.reactions[emoji]?.isEmpty ?? true {
                message.reactions.removeValue(forKey: emoji)
            }
        }
        
        messages[messageIndex] = message
        state.messagesByChannel[channel] = messages
    }
}

