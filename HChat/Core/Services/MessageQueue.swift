//
//  MessageQueue.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  消息发送队列 - 确保消息可靠送达
//

import Foundation
import Observation

@MainActor
@Observable
final class MessageQueue {
    // MARK: - 依赖
    private let persistence: MessagePersistence
    private weak var client: HackChatClient?
    
    // MARK: - 状态
    var pendingCount: Int = 0
    var isProcessing: Bool = false
    
    // MARK: - 配置
    private let maxRetries = 5
    private let retryDelay: UInt64 = 2_000_000_000 // 2秒
    
    // MARK: - 初始化
    init(persistence: MessagePersistence = .shared, client: HackChatClient? = nil) {
        self.persistence = persistence
        self.client = client
        
        // 加载待发送消息数量
        updatePendingCount()
    }
    
    // MARK: - 公开方法
    
    /// 发送消息（自动持久化和队列管理）
    func send(_ message: ChatMessage) async {
        DebugLogger.log("📤 消息加入发送队列: \(message.id)", level: .debug)
        
        // 1. 保存到持久化存储
        do {
            try persistence.savePending(message)
            updatePendingCount()
            
            // 2. 立即尝试发送
            await trySend(message)
            
        } catch {
            DebugLogger.log("❌ 保存消息失败: \(error)", level: .error)
        }
    }
    
    /// 重试所有待发送消息（重连后调用）
    func retryAll() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        DebugLogger.log("🔄 开始重试所有待发送消息", level: .info)
        
        let pending = persistence.getPendingMessages()
        
        for persisted in pending {
            let message = persisted.toChatMessage()
            await trySend(message)
        }
        
        isProcessing = false
        updatePendingCount()
    }
    
    /// 清空队列（用于测试）
    func clearQueue() {
        persistence.clearAll()
        updatePendingCount()
        DebugLogger.log("🗑️ 清空消息队列", level: .warning)
    }
    
    // MARK: - 私有方法
    
    /// 尝试发送单条消息
    private func trySend(_ message: ChatMessage) async {
        guard let client = client else {
            DebugLogger.log("⚠️ 客户端未连接，消息将在重连后发送", level: .warning)
            return
        }
        
        // 检查连接状态
        guard client.isConnected else {
            DebugLogger.log("⚠️ WebSocket 未连接，消息将在重连后发送", level: .warning)
            return
        }
        
        // 检查重试次数
        let pending = persistence.getPendingMessages()
        guard let persisted = pending.first(where: { $0.id == message.id }) else {
            return
        }
        
        if persisted.retryCount >= maxRetries {
            DebugLogger.log("❌ 消息发送失败（超过最大重试次数）: \(message.id)", level: .error)
            try? persistence.updateStatus(messageId: message.id, status: .failed)
            return
        }
        
        // 构建消息 JSON
        var json: [String: Any] = [
            "type": "message",
            "id": message.id,
            "room": message.channel,
            "text": message.text
        ]
        
        // 如果有附件，添加附件信息
        if let attachment = message.attachments.first {
            json["attachment"] = [
                "id": attachment.id,
                "kind": attachment.kind.rawValue,
                "filename": attachment.filename,
                "url": attachment.getUrl?.absoluteString ?? ""
            ]
        }
        
        // 发送到服务器
        client.send(json: json)
        
        // 标记为已发送（等待 ACK）
        try? persistence.updateStatus(messageId: message.id, status: .sent)
        
        DebugLogger.log("✅ 消息已发送: \(message.id)", level: .info)
        
        // 延迟移除（等待服务器确认）
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒后自动移除（未来由 ACK 触发）
            try? persistence.removePending(messageId: message.id)
            updatePendingCount()
        }
    }
    
    /// 更新待发送消息数量
    private func updatePendingCount() {
        pendingCount = persistence.getPendingMessages().count
        DebugLogger.log("📊 待发送消息数量: \(pendingCount)", level: .debug)
    }
    
    /// 处理服务器 ACK（未来实现）
    func handleAck(messageId: String, status: MessageStatus) {
        DebugLogger.log("✅ 收到服务器 ACK: \(messageId) -> \(status.rawValue)", level: .info)
        
        do {
            try persistence.updateStatus(messageId: messageId, status: status)
            
            // 如果已送达，从队列移除
            if status.isCompleted {
                try persistence.removePending(messageId: messageId)
                updatePendingCount()
            }
        } catch {
            DebugLogger.log("❌ 处理 ACK 失败: \(error)", level: .error)
        }
    }
}

