import Foundation

/// 已读回执
public struct ReadReceipt: Identifiable, Codable, Hashable {
    public let id: String                // 回执 ID
    public let messageId: String         // 消息 ID
    public let userId: String            // 已读用户的昵称
    public let timestamp: Date           // 已读时间
    
    public init(id: String = UUID().uuidString, messageId: String, userId: String, timestamp: Date = Date()) {
        self.id = id
        self.messageId = messageId
        self.userId = userId
        self.timestamp = timestamp
    }
}
