//
//  MessageStatusView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  消息状态显示组件
//

import SwiftUI

struct MessageStatusView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(spacing: 4) {
            // 状态图标
            Image(systemName: message.status.icon)
                .font(.caption2)
                .foregroundColor(message.status.color)
            
            // 时间戳
            Text(formatTimestamp(message.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // 重试按钮（仅失败时显示）
            if message.status.canRetry {
                Button {
                    retryMessage()
                } label: {
                    Text("重试")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            // 今天：显示时间
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            // 昨天
            return "昨天 " + date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            // 本周：显示星期
            return date.formatted(.dateTime.weekday().hour().minute())
        } else {
            // 更早：显示日期
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
    
    private func retryMessage() {
        // TODO: 触发消息重试
        DebugLogger.log("🔄 手动重试消息: \(message.id)", level: .info)
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        MessageStatusView(message: ChatMessage(
            id: "1",
            channel: "lobby",
            sender: "Alice",
            text: "发送中...",
            isLocalEcho: true
        ))
        
        MessageStatusView(message: ChatMessage(
            id: "2",
            channel: "lobby",
            sender: "Alice",
            text: "已送达"
        ))
    }
    .padding()
}

