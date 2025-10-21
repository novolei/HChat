//
//  ReplyManager.swift
//  HChat
//
//  Created on 2025-10-21.
//  消息引用/回复管理器

import Foundation
import Observation

@MainActor
@Observable
final class ReplyManager {
    // MARK: - 依赖
    private weak var client: HackChatClient?
    
    // MARK: - 状态
    
    /// 当前正在回复的消息
    var replyingTo: ChatMessage?
    
    // MARK: - 初始化
    
    init(client: HackChatClient? = nil) {
        self.client = client
    }
    
    /// 设置客户端引用（用于延迟注入）
    func setClient(_ client: HackChatClient) {
        self.client = client
    }
    
    // MARK: - 公开方法
    
    /// 设置回复目标
    func setReplyTarget(_ message: ChatMessage) {
        replyingTo = message
        DebugLogger.log("💬 设置回复目标: \(message.sender) - \(message.text.prefix(30))", level: .debug)
    }
    
    /// 清除回复
    func clearReply() {
        if let message = replyingTo {
            DebugLogger.log("❌ 取消回复: \(message.sender)", level: .debug)
        }
        replyingTo = nil
    }
    
    /// 发送回复消息
    func sendReply(text: String) {
        guard let target = replyingTo, let client = client else { return }
        
        DebugLogger.log("💬 发送回复: \(text.prefix(30)) -> \(target.sender)", level: .info)
        
        // 创建引用信息
        let reply = MessageReply.from(target)
        
        // 创建回复消息
        let id = UUID().uuidString
        client.state.markMessageAsSent(id: id)
        
        var message = ChatMessage(
            id: id,
            channel: client.state.currentChannel,
            sender: client.state.myNick,
            text: text,
            replyTo: reply
        )
        message.status = .sending
        
        // 立即显示在界面（乐观更新）
        client.state.appendMessage(message)
        
        // 通过队列发送
        Task {
            // 构建发送的 JSON
            let json: [String: Any] = [
                "type": "message",
                "id": id,
                "room": client.state.currentChannel,
                "text": text,
                "replyTo": [
                    "messageId": reply.messageId,
                    "sender": reply.sender,
                    "text": reply.text,
                    "timestamp": reply.timestamp.timeIntervalSince1970
                ]
            ]
            
            client.send(json: json)
        }
        
        // 清除回复状态
        clearReply()
    }
    
    /// 发送带附件的回复
    func sendReplyWithAttachment(_ attachment: Attachment) {
        guard let target = replyingTo, let client = client else { return }
        
        DebugLogger.log("💬 发送回复（附件）: \(attachment.filename) -> \(target.sender)", level: .info)
        
        // 创建引用信息
        let reply = MessageReply.from(target)
        
        // 创建回复消息
        let msgId = UUID().uuidString
        client.state.markMessageAsSent(id: msgId)
        
        var message = ChatMessage(
            id: msgId,
            channel: client.state.currentChannel,
            sender: client.state.myNick,
            text: "",
            attachments: [attachment],
            replyTo: reply
        )
        message.status = .sending
        
        // 立即显示在界面
        client.state.appendMessage(message)
        
        // 通过队列发送
        Task {
            let json: [String: Any] = [
                "type": "message",
                "id": msgId,
                "room": client.state.currentChannel,
                "text": "",
                "attachment": [
                    "id": attachment.id,
                    "kind": attachment.kind.rawValue,
                    "filename": attachment.filename,
                    "url": attachment.getUrl?.absoluteString ?? ""
                ],
                "replyTo": [
                    "messageId": reply.messageId,
                    "sender": reply.sender,
                    "text": reply.text,
                    "timestamp": reply.timestamp.timeIntervalSince1970
                ]
            ]
            
            client.send(json: json)
        }
        
        // 清除回复状态
        clearReply()
    }
}

