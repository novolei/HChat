import Foundation
import Observation

@MainActor
@Observable
final class ReadReceiptManager {
    private weak var client: HackChatClient?
    private weak var state: ChatState?
    
    /// 已发送的已读回执记录（避免重复发送）
    private var sentReceipts: Set<String> = [] // messageId 集合
    
    init(client: HackChatClient? = nil, state: ChatState? = nil) {
        self.client = client
        self.state = state
    }
    
    func setDependencies(client: HackChatClient, state: ChatState) {
        self.client = client
        self.state = state
    }
    
    /// 标记消息为已读
    func markAsRead(messageId: String, channel: String) {
        guard let client = client, let state = state else { return }
        guard !sentReceipts.contains(messageId) else { return } // 避免重复发送
        
        // 发送已读回执到服务器
        let json: [String: Any] = [
            "type": "read_receipt",
            "messageId": messageId,
            "channel": channel,
            "userId": client.myNick,
            "timestamp": Date().timeIntervalSince1970
        ]
        client.send(json: json)
        
        sentReceipts.insert(messageId)
        DebugLogger.log("✓ 发送已读回执: \(messageId) by \(client.myNick)", level: .debug)
    }
    
    /// 批量标记可见消息为已读
    func markVisibleMessagesAsRead(messages: [ChatMessage]) {
        guard let client = client else { return }
        
        for message in messages {
            // 只标记别人发送的消息
            guard message.sender != client.myNick else { continue }
            // 避免重复标记
            guard !sentReceipts.contains(message.id) else { continue }
            
            markAsRead(messageId: message.id, channel: message.channel)
        }
    }
    
    /// 处理来自服务器的已读回执通知
    func handleReadReceipt(_ obj: [String: Any]) {
        guard let state = state,
              let messageId = obj["messageId"] as? String,
              let channel = obj["channel"] as? String,
              let userId = obj["userId"] as? String,
              let timestamp = obj["timestamp"] as? TimeInterval else { return }
        
        // 忽略自己的回执（本地已处理）
        guard userId != client?.myNick else { return }
        
        // 查找消息并添加已读回执
        if let messageIndex = state.messagesByChannel[channel]?.firstIndex(where: { $0.id == messageId }) {
            var message = state.messagesByChannel[channel]![messageIndex]
            
            // 检查是否已存在该用户的已读回执
            guard !message.readReceipts.contains(where: { $0.userId == userId }) else { return }
            
            let receipt = ReadReceipt(
                messageId: messageId,
                userId: userId,
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
            message.readReceipts.append(receipt)
            
            // ✨ P1: 如果是自己发送的消息，更新状态为已读
            if message.sender == client?.myNick {
                message.status = .read
            }
            
            state.messagesByChannel[channel]?[messageIndex] = message
            
            DebugLogger.log("✓ 收到已读回执: \(messageId) by \(userId)", level: .debug)
        }
    }
    
    /// 清理已发送的回执记录（可选，用于释放内存）
    func clearSentReceipts() {
        sentReceipts.removeAll()
    }
}

