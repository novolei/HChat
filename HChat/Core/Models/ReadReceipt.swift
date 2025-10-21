//
//  ReadReceipt.swift
//  HChat
//
//  Created on 2025-10-21.
//  已读回执模型

import Foundation

/// 已读回执信息
public struct ReadReceipt: Codable, Hashable, Identifiable {
    public let id: String           // 回执 ID
    public let userId: String        // 读者的昵称
    public let readAt: Date          // 已读时间
    
    public init(id: String = UUID().uuidString, userId: String, readAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.readAt = readAt
    }
    
    /// 友好的时间显示
    public var readAtString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: readAt, relativeTo: Date())
    }
}

