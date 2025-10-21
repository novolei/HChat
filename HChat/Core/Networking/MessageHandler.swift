//
//  MessageHandler.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  消息接收和处理逻辑
//

import Foundation

@MainActor
final class MessageHandler {
    private weak var state: ChatState?
    private weak var presenceManager: PresenceManager?
    private weak var reactionManager: ReactionManager?
    
    init(state: ChatState, presenceManager: PresenceManager? = nil, reactionManager: ReactionManager? = nil) {
        self.state = state
        self.presenceManager = presenceManager
        self.reactionManager = reactionManager
    }
    
    /// 设置 PresenceManager（用于延迟注入）
    func setPresenceManager(_ manager: PresenceManager) {
        self.presenceManager = manager
    }
    
    /// 设置 ReactionManager（用于延迟注入）
    func setReactionManager(_ manager: ReactionManager) {
        self.reactionManager = manager
    }
    
    /// 处理接收到的数据
    func handle(data: Data) async {
        guard let state = state else { return }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        // 记录接收的消息
        if let jsonString = String(data: data, encoding: .utf8) {
            let isEncrypted = (obj["text"] as? String)?.hasPrefix("E2EE:") ?? false
            let displayMsg = isEncrypted ? "[加密消息 from \(obj["nick"] ?? "unknown")]" : jsonString
            DebugLogger.logWebSocket(direction: "接收", message: displayMsg, encrypted: isEncrypted)
        }
        
        let type = (obj["type"] as? String) ?? "message"
        
        // 处理不同类型的消息
        switch type {
        case "presence":
            handlePresence(obj, state: state)
        case "nick_change":
            handleNicknameChange(obj, state: state)
        case "dm":
            handleDirectMessage(obj, state: state)
        case "user_joined":
            handleUserJoined(obj, state: state)
        case "user_left":
            handleUserLeft(obj, state: state)
        case "info":
            handleInfo(obj, state: state)
        case "message_ack":
            handleMessageAck(obj)
        case "message_delivered":
            handleMessageDelivered(obj)
        case "status_update":
            handleStatusUpdate(obj)
        case "reaction_added":
            handleReactionAdded(obj)
        case "reaction_removed":
            handleReactionRemoved(obj)
        default:
            handleChatMessage(obj, state: state)
        }
    }
    
    // MARK: - 私有处理方法
    
    private func handlePresence(_ obj: [String: Any], state: ChatState) {
        let room = (obj["room"] as? String) ?? state.currentChannel
        let users = (obj["users"] as? [String]) ?? []
        let count = obj["count"] as? Int
        state.updateOnlineUsers(room: room, users: users, count: count)
        
        // ✨ P1: 批量更新在线用户状态
        presenceManager?.updateOnlineUsers(users, channel: room)
    }
    
    private func handleNicknameChange(_ obj: [String: Any], state: ChatState) {
        let oldNick = (obj["oldNick"] as? String) ?? ""
        let newNick = (obj["newNick"] as? String) ?? ""
        let channel = (obj["channel"] as? String) ?? state.currentChannel
        
        DebugLogger.log("👤 昵称变更: \(oldNick) → \(newNick) (频道: \(channel))", level: .debug)
        
        // 更新该频道所有消息中的发送者昵称
        state.updateNickname(oldNick: oldNick, newNick: newNick, in: channel)
        
        // 显示其他用户的昵称变更通知（不显示自己的）
        if oldNick != state.myNick && newNick != state.myNick {
            state.systemMessage("\(oldNick) 更名为 \(newNick)")
            DebugLogger.log("👤 显示昵称变更通知: \(oldNick) → \(newNick)", level: .debug)
        } else {
            DebugLogger.log("✅ 昵称变更通知已处理（自己）: \(oldNick) → \(newNick)", level: .debug)
        }
    }
    
    private func handleDirectMessage(_ obj: [String: Any], state: ChatState) {
        let msgId = (obj["id"] as? String) ?? UUID().uuidString
        
        // 去重检查
        if state.isMessageAlreadySent(id: msgId) { return }
        
        let from = (obj["from"] as? String) ?? "unknown"
        let to = (obj["to"] as? String) ?? ""
        let text = (obj["text"] as? String) ?? ""
        let ch = "pm/" + ((from == state.myNick) ? to : from)
        
        state.appendMessage(ChatMessage(id: msgId, channel: ch, sender: from, text: text))
    }
    
    private func handleUserJoined(_ obj: [String: Any], state: ChatState) {
        let nick = (obj["nick"] as? String) ?? "someone"
        let channel = (obj["channel"] as? String) ?? state.currentChannel
        DebugLogger.log("👋 用户加入: \(nick) → #\(channel)", level: .debug)
        state.systemMessage("\(nick) 加入了 #\(channel)")
        
        // ✨ P1: 更新在线状态
        presenceManager?.handleUserJoined(nick: nick, channel: channel)
    }
    
    private func handleUserLeft(_ obj: [String: Any], state: ChatState) {
        let nick = (obj["nick"] as? String) ?? "someone"
        let channel = (obj["channel"] as? String) ?? state.currentChannel
        DebugLogger.log("👋 用户离开: \(nick) ← #\(channel)", level: .debug)
        state.systemMessage("\(nick) 离开了 #\(channel)")
        
        // ✨ P1: 更新在线状态
        presenceManager?.handleUserLeft(nick: nick, channel: channel)
    }
    
    private func handleInfo(_ obj: [String: Any], state: ChatState) {
        let text = (obj["text"] as? String) ?? ""
        
        // 过滤昵称相关的 info 消息（保持界面简洁）
        if text.contains("昵称已更改为") || text.hasPrefix("joined #") {
            DebugLogger.log("🚫 过滤 info 消息: \(text)", level: .debug)
            return
        }
        
        // 其他 info 消息可以显示（如果需要）
        // state.systemMessage(text)
    }
    
    private func handleChatMessage(_ obj: [String: Any], state: ChatState) {
        let msgId = (obj["id"] as? String) ?? UUID().uuidString
        let channel = (obj["channel"] as? String) ?? state.currentChannel
        let nick = (obj["nick"] as? String) ?? "server"
        let text = (obj["text"] as? String) ?? ""
        
        DebugLogger.log("📥 收到消息 - ID: \(msgId), nick: \(nick), text: \(text.prefix(30))", level: .debug)
        
        // 解析附件
        var attachments: [Attachment] = []
        if let a = obj["attachment"] as? [String: Any],
           let urlStr = a["url"] as? String,
           let u = URL(string: urlStr) {
            let kind = Attachment.Kind(rawValue: (a["kind"] as? String) ?? "file") ?? .file
            let fn = (a["filename"] as? String) ?? "attachment"
            attachments = [Attachment(kind: kind, filename: fn, contentType: "application/octet-stream", putUrl: nil, getUrl: u, sizeBytes: nil)]
        }
        
        // ✨ P1: 解析引用信息
        var replyTo: MessageReply? = nil
        if let r = obj["replyTo"] as? [String: Any],
           let replyMsgId = r["messageId"] as? String,
           let replySender = r["sender"] as? String,
           let replyText = r["text"] as? String {
            let replyTimestamp = (r["timestamp"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? Date()
            replyTo = MessageReply(
                messageId: replyMsgId,
                sender: replySender,
                text: replyText,
                timestamp: replyTimestamp
            )
            DebugLogger.log("💬 收到回复消息 - 引用: \(replySender)", level: .debug)
        }
        
        // 去重：若是自己刚发的 msgId，则不再追加
        if state.isMessageAlreadySent(id: msgId) {
            DebugLogger.log("✅ 去重成功 - 忽略自己发送的消息 ID: \(msgId)", level: .debug)
            return
        }
        
        DebugLogger.log("📝 添加消息到列表 - ID: \(msgId), from: \(nick)", level: .debug)
        let message = ChatMessage(
            id: msgId,
            channel: channel,
            sender: nick,
            text: text,
            attachments: attachments,
            replyTo: replyTo
        )
        state.appendMessage(message)
        
        // ✅ 使用新的智能通知系统
        Task {
            // 通知所有消息（智能管理器会判断优先级）
            await SmartNotificationManager.shared.notifyMessage(message, myNick: state.myNick)
        }
    }
    
    // MARK: - ✨ P0: ACK 消息处理
    
    /// 处理服务器 ACK 确认（消息已被服务器接收）
    private func handleMessageAck(_ obj: [String: Any]) {
        guard let messageId = obj["messageId"] as? String else { return }
        let status = (obj["status"] as? String) ?? "received"
        
        DebugLogger.log("✅ 收到服务器 ACK: \(messageId) - \(status)", level: .info)
        
        // 通知消息队列更新状态
        NotificationCenter.default.post(
            name: NSNotification.Name("MessageACK"),
            object: nil,
            userInfo: ["messageId": messageId, "status": status]
        )
    }
    
    /// 处理消息送达确认（消息已送达其他用户）
    private func handleMessageDelivered(_ obj: [String: Any]) {
        guard let messageId = obj["messageId"] as? String else { return }
        let deliveredTo = (obj["deliveredTo"] as? [String]) ?? []
        
        DebugLogger.log("📫 消息已送达: \(messageId) → \(deliveredTo.joined(separator: ", "))", level: .info)
        
        // 通知消息队列更新状态为已送达
        NotificationCenter.default.post(
            name: NSNotification.Name("MessageDelivered"),
            object: nil,
            userInfo: ["messageId": messageId, "deliveredTo": deliveredTo]
        )
    }
    
    // MARK: - ✨ P1: 在线状态处理
    
    /// 处理用户状态更新
    private func handleStatusUpdate(_ obj: [String: Any]) {
        presenceManager?.handleStatusUpdate(obj)
    }
    
    // MARK: - ✨ P1: 表情反应处理
    
    /// 处理反应添加通知
    private func handleReactionAdded(_ obj: [String: Any]) {
        reactionManager?.handleReactionAdded(obj)
    }
    
    /// 处理反应移除通知
    private func handleReactionRemoved(_ obj: [String: Any]) {
        reactionManager?.handleReactionRemoved(obj)
    }
}

