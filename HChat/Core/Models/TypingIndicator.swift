//
//  TypingIndicator.swift
//  HChat
//
//  Created on 2025-10-22.
//  正在输入指示器模型

import Foundation

/// 正在输入的用户信息
struct TypingUser: Identifiable, Equatable {
    let id: String  // 用户昵称
    let channel: String
    let timestamp: Date
    
    var nickname: String { id }
    
    /// 是否已过期（超过 3 秒未更新视为停止输入）
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 3.0
    }
}

/// 正在输入状态
enum TypingStatus {
    case idle
    case typing
    case stopped
}

