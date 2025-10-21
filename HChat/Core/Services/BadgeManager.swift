//
//  BadgeManager.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  Badge 角标管理器 - 管理 App 图标上的未读消息数
//

import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
final class BadgeManager {
    // MARK: - 单例
    static let shared = BadgeManager()
    
    // MARK: - 状态
    private(set) var unreadCount: Int = 0
    
    // MARK: - 初始化
    private init() {
        // 从 UserDefaults 恢复未读数
        unreadCount = UserDefaults.standard.integer(forKey: "unreadCount")
    }
    
    // MARK: - 公开方法
    
    /// 增加未读消息数
    func incrementUnread() {
        unreadCount += 1
        saveAndUpdateBadge()
        DebugLogger.log("📬 未读消息数 +1: \(unreadCount)", level: .debug)
    }
    
    /// 设置未读消息数
    func setUnread(_ count: Int) {
        unreadCount = max(0, count)
        saveAndUpdateBadge()
        DebugLogger.log("📬 设置未读消息数: \(unreadCount)", level: .debug)
    }
    
    /// 清空未读消息数（进入 App 时调用）
    func clearUnread() {
        unreadCount = 0
        saveAndUpdateBadge()
        DebugLogger.log("✅ 清空未读消息数", level: .debug)
    }
    
    /// 获取当前未读数（用于通知 badge）
    func getCurrentBadgeCount() -> Int {
        return unreadCount
    }
    
    // MARK: - 私有方法
    
    /// 保存并更新系统 Badge
    private func saveAndUpdateBadge() {
        // 保存到 UserDefaults
        UserDefaults.standard.set(unreadCount, forKey: "unreadCount")
        
        // 更新系统 Badge
        Task {
            await updateSystemBadge()
        }
    }
    
    /// 更新系统 Badge
    private func updateSystemBadge() async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(unreadCount)
            DebugLogger.log("🔢 系统 Badge 已更新: \(unreadCount)", level: .debug)
        } catch {
            DebugLogger.log("❌ 更新 Badge 失败: \(error)", level: .error)
        }
    }
}

