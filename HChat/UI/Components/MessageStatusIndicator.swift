//
//  MessageStatusIndicator.swift
//  HChat
//
//  Created on 2025-10-21.
//  消息发送状态指示器
//

import SwiftUI

/// 消息状态指示器
struct MessageStatusIndicator: View {
    let message: ChatMessage
    let myNick: String
    
    var body: some View {
        // 只为自己发送的消息显示状态
        guard message.sender == myNick else { return AnyView(EmptyView()) }
        
        return AnyView(
            HStack(spacing: 2) {
                // 根据状态显示不同的图标和文本
                switch message.status {
                case .sending:
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text("发送中")
                        .font(.caption2)
                        .foregroundColor(message.status.color)
                    
                case .sent:
                    // ✓ 单勾（灰色）
                    SingleCheckmarkView(color: message.status.color, size: 12)
                    
                case .delivered:
                    // ✓✓ 双勾（灰色）
                    DoubleCheckmarkView(color: message.status.color, size: 12)
                    if !message.hasReadReceipts {
                        Text("已送达")
                            .font(.caption2)
                            .foregroundColor(message.status.color)
                    }
                    
                case .read:
                    // ✓✓ 双勾（蓝色）
                    DoubleCheckmarkView(color: message.status.color, size: 12)
                    
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(message.status.color)
                    Text("发送失败")
                        .font(.caption2)
                        .foregroundColor(message.status.color)
                }
            }
        )
    }
}

/// 消息时间戳和状态组合视图
struct MessageTimestampWithStatus: View {
    let message: ChatMessage
    let myNick: String

    var body: some View {
        HStack(spacing: 4) {
            Text(message.timestamp, style: .time)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(timestampColor)

            if message.sender == myNick {
                statusIcon
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sending:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 11, height: 11)
        
        case .sent:
            // ✓ 单勾（灰色）
            SingleCheckmarkView(color: statusColor, size: 11)
        
        case .delivered:
            // ✓✓ 双勾（灰色）
            DoubleCheckmarkView(color: statusColor, size: 11)
        
        case .read:
            // ✓✓ 双勾（蓝色）
            DoubleCheckmarkView(color: statusColor, size: 11)
        
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(statusColor)
        }
    }

    private var timestampColor: Color {
        message.sender == myNick ? HChatTheme.myMessageText.opacity(0.7) : HChatTheme.tertiaryText.opacity(0.8)
    }

    private var statusColor: Color {
        // ✅ 使用 message.status.color 来区分灰色和蓝色
        message.status.color
    }
}

#Preview {
    VStack(spacing: 20) {
        // 发送中
        MessageStatusIndicator(
            message: ChatMessage(
                id: "1",
                channel: "test",
                sender: "Alice",
                text: "Hello",
                status: .sending
            ),
            myNick: "Alice"
        )
        
        // 已送达服务器
        MessageStatusIndicator(
            message: ChatMessage(
                id: "2",
                channel: "test",
                sender: "Alice",
                text: "Hello",
                status: .sent
            ),
            myNick: "Alice"
        )
        
        // 已送达对方
        MessageStatusIndicator(
            message: ChatMessage(
                id: "3",
                channel: "test",
                sender: "Alice",
                text: "Hello",
                status: .delivered
            ),
            myNick: "Alice"
        )
        
        // 已读
        MessageStatusIndicator(
            message: ChatMessage(
                id: "4",
                channel: "test",
                sender: "Alice",
                text: "Hello",
                status: .read,
                readReceipts: [ReadReceipt(messageId: "4", userId: "Bob")]
            ),
            myNick: "Alice"
        )
        
        // 发送失败
        MessageStatusIndicator(
            message: ChatMessage(
                id: "5",
                channel: "test",
                sender: "Alice",
                text: "Hello",
                status: .failed
            ),
            myNick: "Alice"
        )
    }
    .padding()
}

