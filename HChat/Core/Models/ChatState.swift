//
//  ChatState.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  状态管理：频道、消息、在线用户
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatState {
    // MARK: - 频道相关
    var channels: [Channel] = [Channel(name: "lobby")]
    var currentChannel: String = "lobby"
    
    // MARK: - 消息相关
    var messagesByChannel: [String: [ChatMessage]] = [:]
    private var sentMessageIds = Set<String>()  // 用于去重
    
    // MARK: - 用户相关
    var myNick: String {
        get {
            UserDefaults.standard.string(forKey: "myNick") ?? "iOSUser"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "myNick")
        }
    }
    
    var shouldShowNicknamePrompt: Bool {
        myNick == "iOSUser" || myNick.hasPrefix("iOSUser")
    }
    
    // MARK: - 在线状态
    var onlineByRoom: [String: Set<String>] = [:]
    var onlineCountByRoom: [String: Int] = [:]
    
    // MARK: - 加密相关
    var passphraseForEndToEndEncryption: String = ""
    
    // MARK: - ✨ 会话管理（新增）
    var conversations: [Conversation] = []           // 所有会话列表
    var currentConversation: Conversation?           // 当前活跃会话
    var onlineStatuses: [String: OnlineStatus] = [:] // 用户在线状态映射
    
    // MARK: - 消息操作
    
    /// 添加消息到频道
    func appendMessage(_ m: ChatMessage) {
        DebugLogger.log("➕ appendMessage - ID: \(m.id), channel: \(m.channel), sender: \(m.sender), isLocalEcho: \(m.isLocalEcho)", level: .debug)
        var arr = messagesByChannel[m.channel, default: []]
        arr.append(m)
        messagesByChannel[m.channel] = arr
        
        // 更新频道信息
        if let idx = channels.firstIndex(where: { $0.name == m.channel }) {
            channels[idx].lastMessageAt = m.timestamp
            if m.channel != currentChannel {
                channels[idx].unreadCount += 1
            }
        }
    }
    
    /// 记录已发送的消息 ID（用于去重）
    func markMessageAsSent(id: String) {
        sentMessageIds.insert(id)
    }
    
    /// 检查消息是否已发送（用于去重）
    func isMessageAlreadySent(id: String) -> Bool {
        let exists = sentMessageIds.contains(id)
        if exists {
            sentMessageIds.remove(id)
        }
        return exists
    }
    
    /// 更新频道中所有消息的发送者昵称
    func updateNickname(oldNick: String, newNick: String, in channel: String) {
        guard var messages = messagesByChannel[channel] else { return }
        
        for index in messages.indices {
            if messages[index].sender == oldNick {
                let oldMsg = messages[index]
                messages[index] = ChatMessage(
                    id: oldMsg.id,
                    channel: oldMsg.channel,
                    sender: newNick,
                    text: oldMsg.text,
                    timestamp: oldMsg.timestamp,
                    attachments: oldMsg.attachments,
                    isLocalEcho: oldMsg.isLocalEcho
                )
            }
        }
        
        messagesByChannel[channel] = messages
    }
    
    /// 清空当前频道的消息
    func clearCurrentChannelMessages() {
        messagesByChannel[currentChannel] = []
    }
    
    /// 更新频道中的指定消息
    /// 这个方法确保触发 @Observable 的变更检测
    func updateMessage(in channel: String, messageId: String, updateBlock: (inout ChatMessage) -> Void) {
        var messages = messagesByChannel[channel] ?? []
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            DebugLogger.log("⚠️ updateMessage - 消息未找到: \(messageId.prefix(8)) in channel: \(channel)", level: .warning)
            return
        }
        
        let before = messages[index].reactions.count
        updateBlock(&messages[index])
        let after = messages[index].reactions.count
        
        // 🔥 关键：创建全新字典以强制触发 @Observable
        var newDict = messagesByChannel
        newDict[channel] = messages
        messagesByChannel = newDict
        
        DebugLogger.log("🔄 updateMessage - messageId: \(messageId.prefix(8)), reactions: \(before) → \(after), dict updated", level: .info)
    }
    
    /// 添加系统消息
    func systemMessage(_ text: String) {
        appendMessage(ChatMessage(channel: currentChannel, sender: "system", text: text))
    }
    
    /// 加入频道
    func joinChannel(_ name: String) {
        if !channels.contains(where: { $0.name == name }) {
            channels.append(Channel(name: name))
        }
        currentChannel = name
    }
    
    /// 更新在线用户列表
    func updateOnlineUsers(room: String, users: [String], count: Int?) {
        onlineByRoom[room] = Set(users)
        onlineCountByRoom[room] = count ?? users.count
    }
    
    // MARK: - ✨ P0: 消息状态更新
    
    /// 更新消息状态
    func updateMessageStatus(id: String, channel: String, status: MessageStatus) {
        guard var messages = messagesByChannel[channel] else { return }
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        
        messages[index].status = status
        messagesByChannel[channel] = messages
        
        DebugLogger.log("🔄 消息状态已更新: \(id) -> \(status.rawValue)", level: .debug)
    }
    
    /// 批量更新消息状态
    func updateMessagesStatus(ids: [String], channel: String, status: MessageStatus) {
        guard var messages = messagesByChannel[channel] else { return }
        
        var updated = false
        for id in ids {
            if let index = messages.firstIndex(where: { $0.id == id }) {
                messages[index].status = status
                updated = true
            }
        }
        
        if updated {
            messagesByChannel[channel] = messages
            DebugLogger.log("🔄 批量更新消息状态: \(ids.count) 条 -> \(status.rawValue)", level: .debug)
        }
    }
    
    // MARK: - ✨ 会话管理方法
    
    /// 创建或获取私聊会话
    func createOrGetDM(with userId: String) -> Conversation {
        let conversationId = "dm:\(userId)"
        
        // 查找已存在的会话
        if let existing = conversations.first(where: { $0.id == conversationId }) {
            return existing
        }
        
        // 创建新会话
        let conversation = Conversation(
            id: conversationId,
            type: .dm,
            title: userId,
            otherUserId: userId,
            isOnline: onlineStatuses[userId]?.isOnline ?? false
        )
        
        conversations.append(conversation)
        sortConversations()
        
        DebugLogger.log("✨ 创建新私聊会话: \(userId)", level: .info)
        return conversation
    }
    
    /// 创建或获取频道会话
    func createOrGetChannelConversation(channelId: String, title: String? = nil) -> Conversation {
        let conversationId = "channel:\(channelId)"
        
        // 查找已存在的会话
        if let existing = conversations.first(where: { $0.id == conversationId }) {
            return existing
        }
        
        // 创建新会话
        let conversation = Conversation(
            id: conversationId,
            type: .channel,
            title: title ?? channelId,
            channelId: channelId,
            memberCount: onlineCountByRoom[channelId] ?? 0
        )
        
        conversations.append(conversation)
        sortConversations()
        
        return conversation
    }
    
    /// 更新会话的最后消息
    func updateConversationLastMessage(_ conversationId: String, message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        
        conversations[index].lastMessage = message
        conversations[index].updatedAt = message.timestamp
        
        // 重新排序（最新消息在最上面）
        sortConversations()
    }
    
    /// 增加会话未读数
    func incrementConversationUnread(_ conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        
        // 如果不是当前会话，增加未读数
        if currentConversation?.id != conversationId {
            conversations[index].unreadCount += 1
        }
    }
    
    /// 清空会话未读数
    func clearConversationUnread(_ conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        conversations[index].unreadCount = 0
    }
    
    /// 置顶/取消置顶会话
    func toggleConversationPin(_ conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        conversations[index].isPinned.toggle()
        sortConversations()
    }
    
    /// 免打扰/取消免打扰会话
    func toggleConversationMute(_ conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        conversations[index].isMuted.toggle()
    }
    
    /// 删除会话
    func deleteConversation(_ conversationId: String) {
        conversations.removeAll { $0.id == conversationId }
        
        // 如果删除的是当前会话，清空当前会话
        if currentConversation?.id == conversationId {
            currentConversation = nil
        }
    }
    
    /// 更新用户在线状态
    func updateUserStatus(_ userId: String, isOnline: Bool, lastSeen: Date? = nil) {
        // 更新状态映射
        if var status = onlineStatuses[userId] {
            status.isOnline = isOnline
            status.lastSeen = lastSeen ?? (isOnline ? nil : Date())
            onlineStatuses[userId] = status
        } else {
            onlineStatuses[userId] = OnlineStatus(
                userId: userId,
                isOnline: isOnline,
                lastSeen: lastSeen
            )
        }
        
        // 更新相关私聊会话的在线状态
        if let index = conversations.firstIndex(where: { $0.type == .dm && $0.otherUserId == userId }) {
            conversations[index].isOnline = isOnline
        }
    }
    
    /// 对会话列表排序
    private func sortConversations() {
        conversations.sort { conv1, conv2 in
            // 1. 置顶的在最上面
            if conv1.isPinned != conv2.isPinned {
                return conv1.isPinned
            }
            
            // 2. 按最后更新时间排序
            return conv1.updatedAt > conv2.updatedAt
        }
    }
}

