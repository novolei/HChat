//
//  TypingIndicatorManager.swift
//  HChat
//
//  Created on 2025-10-22.
//  管理正在输入状态

import Foundation
import Combine

@MainActor
@Observable
class TypingIndicatorManager {
    // MARK: - Properties
    
    /// 当前正在输入的用户列表（按频道分组）
    private(set) var typingUsersByChannel: [String: [TypingUser]] = [:]
    
    /// 定时器，用于清理过期的输入状态
    nonisolated(unsafe) private var cleanupTimer: Timer?
    
    weak var client: HackChatClient?
    
    // MARK: - Initialization
    
    init() {
        startCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    func setClient(_ client: HackChatClient) {
        self.client = client
    }
    
    // MARK: - Public Methods
    
    /// 发送"正在输入"事件
    func sendTypingStatus(channel: String) {
        guard let client = client else { return }
        
        let message: [String: Any] = [
            "cmd": "typing",
            "channel": channel,
            "nick": client.myNick
        ]
        
        client.send(json: message)
        DebugLogger.log("📝 发送正在输入状态: \(channel)", level: .debug)
    }
    
    /// 处理接收到的"正在输入"事件
    func handleTypingEvent(from nickname: String, in channel: String) {
        guard let client = client, nickname != client.myNick else { return }
        
        let typingUser = TypingUser(
            id: nickname,
            channel: channel,
            timestamp: Date()
        )
        
        var users = typingUsersByChannel[channel, default: []]
        
        // 移除该用户的旧记录
        users.removeAll { $0.id == nickname }
        
        // 添加新记录
        users.append(typingUser)
        
        typingUsersByChannel[channel] = users
        
        DebugLogger.log("👀 \(nickname) 正在 \(channel) 输入", level: .debug)
    }
    
    /// 获取指定频道正在输入的用户
    func typingUsers(in channel: String) -> [TypingUser] {
        typingUsersByChannel[channel, default: []].filter { !$0.isExpired }
    }
    
    /// 获取指定频道正在输入的用户昵称列表
    func typingNicknames(in channel: String) -> [String] {
        typingUsers(in: channel).map { $0.nickname }
    }
    
    /// 清理过期的输入状态
    func cleanupExpiredTypingUsers() {
        for (channel, users) in typingUsersByChannel {
            let activeUsers = users.filter { !$0.isExpired }
            if activeUsers.isEmpty {
                typingUsersByChannel.removeValue(forKey: channel)
            } else {
                typingUsersByChannel[channel] = activeUsers
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cleanupExpiredTypingUsers()
            }
        }
    }
}

