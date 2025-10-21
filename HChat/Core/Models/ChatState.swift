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
}

