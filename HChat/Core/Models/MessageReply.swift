//
//  MessageReply.swift
//  HChat
//
//  Created on 2025-10-21.
//  消息引用/回复模型

import Foundation

/// 消息引用信息（用于回复功能）
public struct MessageReply: Codable, Hashable {
    public let messageId: String     // 被引用消息的 ID
    public let sender: String         // 被引用消息的发送者
    public let text: String           // 被引用消息的文本（截断）
    public let timestamp: Date        // 被引用消息的时间
    
    public init(messageId: String, sender: String, text: String, timestamp: Date = Date()) {
        self.messageId = messageId
        self.sender = sender
        // 截断长文本（最多100字符）
        self.text = String(text.prefix(100))
        self.timestamp = timestamp
    }
    
    /// 从 ChatMessage 创建引用
    public static func from(_ message: ChatMessage) -> MessageReply {
        MessageReply(
            messageId: message.id,
            sender: message.sender,
            text: message.text,
            timestamp: message.timestamp
        )
    }
    
    /// 显示用的简短文本
    public var displayText: String {
        if text.isEmpty {
            return "[附件消息]"
        }
        return text.count > 50 ? "\(text.prefix(50))..." : text
    }
}

