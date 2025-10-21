//
//  UserStatus.swift
//  HChat
//
//  Created on 2025-10-21.
//  用户在线状态模型

import Foundation
import SwiftUI

/// 用户在线状态
enum UserStatus: String, Codable {
    case online     // 🟢 在线
    case away       // 🟡 离开（长时间无操作）
    case busy       // 🔴 忙碌（用户主动设置）
    case offline    // ⚪ 离线
    
    /// 状态对应的颜色
    var color: Color {
        switch self {
        case .online: return .green
        case .away: return .yellow
        case .busy: return .red
        case .offline: return .gray
        }
    }
    
    /// 状态图标
    var icon: String {
        switch self {
        case .online: return "circle.fill"
        case .away: return "moon.fill"
        case .busy: return "minus.circle.fill"
        case .offline: return "circle"
        }
    }
    
    /// 状态显示名称
    var displayName: String {
        switch self {
        case .online: return "在线"
        case .away: return "离开"
        case .busy: return "忙碌"
        case .offline: return "离线"
        }
    }
    
    /// Emoji 表示
    var emoji: String {
        switch self {
        case .online: return "🟢"
        case .away: return "🟡"
        case .busy: return "🔴"
        case .offline: return "⚪"
        }
    }
}

/// 用户在线信息
struct UserPresence: Codable, Identifiable {
    let id: String              // 用户 ID（昵称）
    var status: UserStatus      // 状态
    var lastSeen: Date          // 最后活跃时间
    var channel: String?        // 当前所在频道
    
    /// 是否在线（online 或 away）
    var isOnline: Bool {
        status == .online || status == .away
    }
    
    /// 最后活跃时间的友好显示
    var lastSeenString: String {
        let now = Date()
        let interval = now.timeIntervalSince(lastSeen)
        
        if interval < 60 {
            return "刚刚活跃"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) 分钟前活跃"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) 小时前活跃"
        } else {
            let days = Int(interval / 86400)
            return "\(days) 天前活跃"
        }
    }
    
    /// 初始化
    init(id: String, status: UserStatus = .offline, lastSeen: Date = Date(), channel: String? = nil) {
        self.id = id
        self.status = status
        self.lastSeen = lastSeen
        self.channel = channel
    }
}

