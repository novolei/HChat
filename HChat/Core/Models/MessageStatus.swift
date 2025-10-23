//
//  MessageStatus.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  消息状态枚举 - 用于追踪消息送达情况
//

import Foundation
import SwiftUI

/// 消息送达状态
public enum MessageStatus: String, Codable {
    case sending    // 📤 发送中
    case sent       // ✓ 已送达服务器
    case delivered  // ✓✓ 已送达对方
    case read       // ✓✓ 已读
    case failed     // ❌ 发送失败
    
    /// 状态图标
    var icon: String {
        switch self {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    /// 状态颜色
    var color: Color {
        switch self {
        case .sending:
            return .gray
        case .sent:
            return .gray
        case .delivered:
            return .gray  // ✅ 灰色双勾（已送达但未读）
        case .read:
            return .blue  // ✅ 蓝色双勾（已读）
        case .failed:
            return .red
        }
    }
    
    /// 是否可重试
    var canRetry: Bool {
        self == .failed
    }
    
    /// 是否已完成
    var isCompleted: Bool {
        self == .delivered || self == .read
    }
}
