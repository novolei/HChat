//
//  PresenceManager.swift
//  HChat
//
//  Created on 2025-10-21.
//  在线状态管理器

import Foundation
import Observation

@MainActor
@Observable
final class PresenceManager {
    // MARK: - 依赖
    private weak var client: HackChatClient?
    
    // MARK: - 状态
    
    /// 所有用户的在线状态（昵称 -> 状态信息）
    var userPresences: [String: UserPresence] = [:]
    
    /// 自己的状态
    var myStatus: UserStatus = .online {
        didSet {
            if myStatus != oldValue {
                broadcastMyStatus()
            }
        }
    }
    
    /// 离开检测定时器（5分钟无操作自动设为离开）
    nonisolated(unsafe) private var awayTimer: Timer?
    private let awayTimeout: TimeInterval = 300 // 5分钟
    
    // MARK: - 初始化
    
    init(client: HackChatClient? = nil) {
        self.client = client
        setupAwayDetection()
    }
    
    deinit {
        awayTimer?.invalidate()
    }
    
    // MARK: - 公开方法
    
    /// 设置客户端引用
    func setClient(_ client: HackChatClient) {
        self.client = client
    }
    
    /// 更新自己的状态
    func updateMyStatus(_ status: UserStatus) {
        myStatus = status
        DebugLogger.log("👤 状态更新: \(status.emoji) \(status.displayName)", level: .info)
    }
    
    /// 获取用户状态
    func getUserStatus(_ userId: String) -> UserStatus {
        return userPresences[userId]?.status ?? .offline
    }
    
    /// 获取用户在线信息
    func getUserPresence(_ userId: String) -> UserPresence? {
        return userPresences[userId]
    }
    
    /// 用户活动（重置离开定时器）
    func userActivity() {
        resetAwayTimer()
        
        // 如果当前是离开状态，自动恢复为在线
        if myStatus == .away {
            updateMyStatus(.online)
        }
    }
    
    /// 处理收到的状态更新
    func handleStatusUpdate(_ data: [String: Any]) {
        guard let userId = data["nick"] as? String else {
            DebugLogger.log("⚠️ 状态更新缺少 nick 字段", level: .warning)
            return
        }
        
        let statusRaw = (data["status"] as? String) ?? "online"
        let status = UserStatus(rawValue: statusRaw) ?? .online
        
        let timestamp = (data["timestamp"] as? TimeInterval) ?? Date().timeIntervalSince1970
        let lastSeen = Date(timeIntervalSince1970: timestamp)
        
        let channel = data["channel"] as? String
        
        // 更新或创建用户状态
        userPresences[userId] = UserPresence(
            id: userId,
            status: status,
            lastSeen: lastSeen,
            channel: channel
        )
        
        DebugLogger.log("👥 用户状态更新: \(userId) -> \(status.emoji) \(status.displayName)", level: .debug)
    }
    
    /// 处理用户加入频道
    func handleUserJoined(nick: String, channel: String) {
        if var presence = userPresences[nick] {
            presence.status = .online
            presence.lastSeen = Date()
            presence.channel = channel
            userPresences[nick] = presence
        } else {
            userPresences[nick] = UserPresence(
                id: nick,
                status: .online,
                lastSeen: Date(),
                channel: channel
            )
        }
        
        DebugLogger.log("👋 用户上线: \(nick) 加入 #\(channel)", level: .debug)
    }
    
    /// 处理用户离开频道
    func handleUserLeft(nick: String, channel: String) {
        if var presence = userPresences[nick] {
            presence.status = .offline
            presence.lastSeen = Date()
            userPresences[nick] = presence
        }
        
        DebugLogger.log("👋 用户离线: \(nick) 离开 #\(channel)", level: .debug)
    }
    
    /// 批量更新在线用户（来自 presence/who 响应）
    func updateOnlineUsers(_ userList: [String], channel: String) {
        for nick in userList {
            if var presence = userPresences[nick] {
                presence.status = .online
                presence.lastSeen = Date()
                presence.channel = channel
                userPresences[nick] = presence
            } else {
                userPresences[nick] = UserPresence(
                    id: nick,
                    status: .online,
                    lastSeen: Date(),
                    channel: channel
                )
            }
        }
        
        DebugLogger.log("📊 批量更新在线用户: \(userList.count) 人在 #\(channel)", level: .debug)
    }
    
    // MARK: - 私有方法
    
    /// 广播自己的状态
    private func broadcastMyStatus() {
        guard let client = client else { return }
        
        client.send(json: [
            "type": "status_update",
            "status": myStatus.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        DebugLogger.log("📡 广播状态: \(myStatus.emoji) \(myStatus.displayName)", level: .debug)
    }
    
    /// 设置离开检测
    private func setupAwayDetection() {
        awayTimer = Timer.scheduledTimer(withTimeInterval: awayTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.myStatus == .online {
                    self.updateMyStatus(.away)
                    DebugLogger.log("⏰ 长时间无操作，自动设为离开", level: .info)
                }
            }
        }
    }
    
    /// 重置离开定时器
    private func resetAwayTimer() {
        awayTimer?.invalidate()
        setupAwayDetection()
    }
}

