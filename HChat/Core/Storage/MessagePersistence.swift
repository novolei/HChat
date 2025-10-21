//
//  MessagePersistence.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  消息持久化服务 - 确保消息不丢失
//

import Foundation

/// 持久化的消息结构
struct PersistedMessage: Codable {
    let id: String
    let channel: String
    let sender: String
    let text: String
    let timestamp: Date
    var status: MessageStatus
    var retryCount: Int
    let attachments: [AttachmentData]?
    
    struct AttachmentData: Codable {
        let id: String
        let kind: String
        let filename: String
        let url: String
    }
    
    /// 转换为 ChatMessage
    func toChatMessage() -> ChatMessage {
        let attachmentModels = attachments?.compactMap { data -> Attachment? in
            guard let url = URL(string: data.url),
                  let kind = Attachment.Kind(rawValue: data.kind) else {
                return nil
            }
            return Attachment(
                kind: kind,
                filename: data.filename,
                contentType: "application/octet-stream",
                putUrl: nil,
                getUrl: url,
                sizeBytes: nil
            )
        } ?? []
        
        return ChatMessage(
            id: id,
            channel: channel,
            sender: sender,
            text: text,
            timestamp: timestamp,
            attachments: attachmentModels,
            isLocalEcho: status == .sending
        )
    }
    
    /// 从 ChatMessage 创建
    static func from(_ message: ChatMessage, status: MessageStatus = .sending) -> PersistedMessage {
        let attachmentData = message.attachments.map { attachment in
            AttachmentData(
                id: attachment.id,
                kind: attachment.kind.rawValue,
                filename: attachment.filename,
                url: attachment.getUrl?.absoluteString ?? ""
            )
        }
        
        return PersistedMessage(
            id: message.id,
            channel: message.channel,
            sender: message.sender,
            text: message.text,
            timestamp: message.timestamp,
            status: status,
            retryCount: 0,
            attachments: attachmentData.isEmpty ? nil : attachmentData
        )
    }
}

/// 消息持久化管理器
@MainActor
class MessagePersistence {
    // UserDefaults 键
    private let pendingMessagesKey = "pendingMessages"
    private let allMessagesKey = "allMessages"
    
    // 单例
    static let shared = MessagePersistence()
    
    private init() {}
    
    // MARK: - 待发送消息管理
    
    /// 保存待发送消息
    func savePending(_ message: ChatMessage) throws {
        var pending = getPendingMessages()
        let persisted = PersistedMessage.from(message, status: .sending)
        pending.append(persisted)
        
        let data = try JSONEncoder().encode(pending)
        UserDefaults.standard.set(data, forKey: pendingMessagesKey)
        
        DebugLogger.log("💾 保存待发送消息: \(message.id)", level: .debug)
    }
    
    /// 获取所有待发送消息
    func getPendingMessages() -> [PersistedMessage] {
        guard let data = UserDefaults.standard.data(forKey: pendingMessagesKey),
              let messages = try? JSONDecoder().decode([PersistedMessage].self, from: data) else {
            return []
        }
        return messages
    }
    
    /// 移除待发送消息
    func removePending(messageId: String) throws {
        var pending = getPendingMessages()
        pending.removeAll { $0.id == messageId }
        
        let data = try JSONEncoder().encode(pending)
        UserDefaults.standard.set(data, forKey: pendingMessagesKey)
        
        DebugLogger.log("🗑️ 移除待发送消息: \(messageId)", level: .debug)
    }
    
    /// 更新消息状态
    func updateStatus(messageId: String, status: MessageStatus) throws {
        var pending = getPendingMessages()
        
        if let index = pending.firstIndex(where: { $0.id == messageId }) {
            pending[index].status = status
            
            let data = try JSONEncoder().encode(pending)
            UserDefaults.standard.set(data, forKey: pendingMessagesKey)
            
            DebugLogger.log("✏️ 更新消息状态: \(messageId) -> \(status.rawValue)", level: .debug)
        }
    }
    
    /// 增加重试次数
    func incrementRetry(messageId: String) throws {
        var pending = getPendingMessages()
        
        if let index = pending.firstIndex(where: { $0.id == messageId }) {
            pending[index].retryCount += 1
            
            let data = try JSONEncoder().encode(pending)
            UserDefaults.standard.set(data, forKey: pendingMessagesKey)
            
            DebugLogger.log("🔄 消息重试次数 +1: \(messageId) (第 \(pending[index].retryCount) 次)", level: .debug)
        }
    }
    
    // MARK: - 消息历史管理（未来扩展）
    
    /// 保存消息到历史记录
    func saveToHistory(_ message: ChatMessage) throws {
        // TODO: 实现完整的消息历史存储
        // 可以使用 Core Data 或 SQLite
        // 支持分页查询、搜索等
    }
    
    /// 获取频道消息（分页）
    func getMessages(channel: String, limit: Int = 50, offset: Int = 0) -> [ChatMessage] {
        // TODO: 从本地数据库加载历史消息
        return []
    }
    
    /// 清空所有数据（用于测试）
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: pendingMessagesKey)
        UserDefaults.standard.removeObject(forKey: allMessagesKey)
        DebugLogger.log("🗑️ 清空所有持久化数据", level: .warning)
    }
}

